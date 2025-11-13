---- EDITABLE PARAMETERS (you can change these)

-- The port of the python server that will do the neural network computations.
local PORT = 2022

-- How many tiles the player can "see" in any direction.
local VISION_SIZE = 6;



---- LIBRARY IMPORTS
local socket = require('socket')



---- CONSTANT VARIABLES

-- Important RAM addresses.
local ADDRESS_TILES = 0x0500;       -- Array<int>*  : The tile array/matrix
local ADDRESS_PAGE = 0x006D;        -- int*         : The current page within the level
local ADDRESS_HPOS = 0x0086;        -- int*         : The players horizontal position (in the current page)
local ADDRESS_VPOS = 0x03B8;        -- int*         : The players vertical position
local ADDRESS_SPRITES = 0x000F;     -- Array<int>*  : The sprite array
local ADDRESS_EPAGE = 0x006E;       -- Array<int>*  : The page of the sprites within the level
local ADDRESS_EHPOS = 0x0087;       -- Array<int>*  : The horizontal position of the sprites
local ADDRESS_EVPOS = 0x00CF;       -- Array<int>*  : The vertical position of the sprites

-- How wide and tall a RAM page is in tiles.
local PAGE_HEIGHT = 13;
local PAGE_WIDTH = 16;

-- The size of each sprite/tile in pixels.
local SPRITE_WIDTH = 8;
local TILE_WIDTH = 16;

-- The tile values which will be considered "air".
local AIR_VALUES = {0x00, 0x24, 0x25, 0xC2, 0XC3, 0xC5};



---- SCRIPT VARIABLES

-- table<string, boolean> : Keys that are currently being pressed.
local keyInputs;

-- int : The number of inputs to the network.
local inputSize = (VISION_SIZE*2+1)^2;



---- UTILITY FUNCTIONS

-- Returns true if the table contains the value, false otherwise.
function tableContains(table, value)
    for i = 1, #table do
        if table[i] == value then
            return true
        end
    end
  return false
end

-- Get the player's position (top left of sprite) in world coordinates.
function getPlayerPosition()
    -- Calculated as (screen position + page_width*number_of_pages_cleared).
    local playerX = memory.readbyte(ADDRESS_HPOS) + (PAGE_WIDTH*TILE_WIDTH)*memory.readbyte(ADDRESS_PAGE);
    
    -- Calcualted as (screen position - mario_height).
    local playerY = memory.readbyte(ADDRESS_VPOS) - TILE_WIDTH;

    -- Return the player's position.
    return playerX, playerY;
end

-- Check the tile (dx, dy) tiles away from mario. Returns 1 if it is a block, 0 if it is air.
function getTile(playerX, playerY, dx, dy)
    -- Get the (x,y) position of the tile in world coordinates.
    local x = playerX + SPRITE_WIDTH + TILE_WIDTH*dx;
    local y = playerY + TILE_WIDTH*dy;

    -- Get the (x,y) index of the tile in the current page.
    local xIndex = math.floor((x % (PAGE_WIDTH*TILE_WIDTH)) / TILE_WIDTH);
    local yIndex = math.floor(y / TILE_WIDTH);  

    -- If either location is out out of the screen, return 1.
    if xIndex >= PAGE_WIDTH or x < 0 then return 0; end
    if yIndex >= PAGE_HEIGHT or y < 0 then return 0; end

    -- The tile could be in one of two different "pages" in RAM.
    local page = math.floor(x / (PAGE_WIDTH*TILE_WIDTH)) % 2;

    -- Using the tile index and page index, find the address of the tile in RAM.
    -- Calcualted as (array_address + page_offset + y_row + x_col)
    local address = ADDRESS_TILES + page*PAGE_HEIGHT*PAGE_WIDTH + yIndex*PAGE_WIDTH + xIndex;
    
    -- Decide if there is a block at that address.
    local tileType = memory.readbyte(address);
    local isAir = tableContains(AIR_VALUES, tileType);
    
    -- Return the result.
    if isAir then return 0; end
    return 1;
end

-- Return all of the sprite objects (enemies, powerups, moving objects, etc).
function getSprites()
    local sprites = {};

    -- Check every sprite slot.
    for slot=0,4 do
        -- If something is in the slot, add it to the sprite list.
        if memory.readbyte(ADDRESS_SPRITES+slot) == 1 then
            local spriteX = memory.readbyte(ADDRESS_EHPOS + slot) + (PAGE_WIDTH*TILE_WIDTH)*memory.readbyte(ADDRESS_EPAGE + slot);
            local spriteY = memory.readbyte(ADDRESS_EVPOS + slot) - SPRITE_WIDTH - TILE_WIDTH;

            sprites[#sprites+1] = {["x"]=spriteX, ["y"]=spriteY};
        end
    end

    -- Return the filled list.
    return sprites;
end

-- Return the input vector that will be fead to the neural network.
function getInputs()
    local inputs = {};

    -- Get the player's position in world coordinates.
    local playerX, playerY = getPlayerPosition();

    -- Get all of the currently active sprites.
    local sprites = getSprites();

    -- Build the input array.
    for dy=-VISION_SIZE,VISION_SIZE do
        for dx=-VISION_SIZE,VISION_SIZE do
            -- The tile (0 or 1) will be used as input.
            inputs[#inputs+1] = getTile(playerX, playerY, dx,dy);

            -- Unless a sprite is in the space, and then -1 will be used.
            for i=1,#sprites do
                -- Check how far from the space the sprite is.
                distx = math.abs(sprites[i]["x"] - (playerX + dx*TILE_WIDTH));
                disty = math.abs(sprites[i]["y"] - (playerY + dy*TILE_WIDTH));

                -- If it is within half a tile, it is in the sapce.
                if distx <= SPRITE_WIDTH and disty <= SPRITE_WIDTH then
                    inputs[#inputs] = -1;
                end
            end
        end
    end

    -- Return the inputs array.
    return inputs;
end

-- Will send the input vector to the python server.
function sendInputs(sock)
    -- Get the network inputs.
    local inputs = getInputs();

    -- Create a message string to send over TCP.
    local message = ""
    for i=1,#inputs do
        message = message .. inputs[i] .. " "
    end
    
    -- Add a message terminator.
    message = message .. "END"

    -- Send the message.
    sock:send(message);
end



---- CONNECT TO PYTHON SERVER

-- Connect to the server.
local sock = assert(socket.tcp());
local success, err = sock:connect("localhost", PORT);

-- If there was an error, abort.
if not success then
    print("[NOTICE]: Could not connect to python server. Aborting.");
    return; 
end



---- MAIN GAME LOOP

while true do
    -- Get the controller inputs every frame.
    keyInputs = input.get()

    -- The escape key stops the script.
    if keyInputs["Escape"] then break; end

    -- Send the current network to the python server.
    sendInputs(sock);

    -- Wait for the server to finish processing.
    local response, err = sock:receive();
    if not response then
        print("[NOTICE]: Python server disconnected. Aborting.");
        break; 
    end

    -- TODO: Collect key inputs from the server.

    -- Advance the frame.
    emu.frameadvance();
end



---- GRACEFULLY CLOSE THE CONNECTION
sock:close()
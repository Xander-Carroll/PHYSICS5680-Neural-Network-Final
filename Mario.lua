---- CONSTANT VARIABLES

-- Important RAM addresses
local ADDRESS_TILES = 0x0500;   -- Array<int>*   : The tile array/matrix
local ADDRESS_PAGE = 0x006D;    -- int*          : The current page within the level
local ADDRESS_HPOS = 0x0086;    -- int*          : The players horizontal position (in the current page)
local ADDRESS_VPOS = 0x03B8;    -- int*          : The players vertical position

-- How wide and tall a RAM page is in tiles
local PAGE_HEIGHT = 13;
local PAGE_WIDTH = 16;

-- The size of each sprite/tile in pixels
local SPRITE_WIDTH = 8;
local TILE_WIDTH = 16;

-- The tile values which will be considered "air"
local AIR_VALUES = {0x00, 0x24, 0x25, 0xC2, 0XC3, 0xC5};


---- SCRIPT VARIABLES

-- table<string, boolean> : Keys that are currently being pressed
local inputs;

-- int, int : The player's global world position
local playerX, playerY;



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

-- Get the player's position in world coordinates.
function getPlayerPosition()
    -- Get the player's x and y position in the world. (Top left of mario).

    -- Calculated as (screen position + page_width*number_of_pages_cleared)
    playerX = memory.readbyte(ADDRESS_HPOS) + (PAGE_WIDTH*TILE_WIDTH)*memory.readbyte(ADDRESS_PAGE);
    
    -- Calcualted as (screen position - mario_height)
    playerY = memory.readbyte(ADDRESS_VPOS) - TILE_WIDTH;
end

-- Check the tile (dx, dy) tiles away from mario. Returns 1 if there is a tile, 0 otherwise.
function getTile(dx, dy)
    -- Get the (x,y) position of the tile in world coordinates.
    local x = playerX + SPRITE_WIDTH + TILE_WIDTH*dx;
    local y = playerY + TILE_WIDTH*dy;

    -- Get the (x,y) index of the tile in the current page.
    local xIndex = math.floor((x % (PAGE_WIDTH*TILE_WIDTH)) / TILE_WIDTH);
    local yIndex = math.floor(y / TILE_WIDTH);  

    -- If either location is out out of the screen, return 1.
    if xIndex >= PAGE_WIDTH or x < 0 then return 1; end
    if yIndex >= PAGE_HEIGHT or y < 0 then return 1; end

    -- The tile could be in one of two different "pages" in RAM.
    local page = math.floor(x / (PAGE_WIDTH*TILE_WIDTH)) % 2;

    -- Using the tile index and page index, find the address of the tile in RAM.
    -- Calcualted as (array_address + page_offset + y_row + x_col)
    local address = ADDRESS_TILES + page*PAGE_HEIGHT*PAGE_WIDTH + yIndex*PAGE_WIDTH + xIndex;
    
    -- Decide if there is a tile at that address.
    local tileType = memory.readbyte(address);
    local isAir = tableContains(AIR_VALUES, tileType);
    
    -- Return the result.
    if isAir then return 0; end
    return 1;
end



---- MAIN GAME LOOP

while true do
    -- TODO: Remove. Get the inputs every frame.
    inputs = input.get()

    -- Get the player's position in world coordinates.
    getPlayerPosition();

    -- TODO: Remove. 
    if inputs["Insert"] then
        console.clear();
        for y=-5,2 do
            local line = ""
            for x=-4,4 do
                if x==0 and y==0 then 
                    line = line .. "* ";
                else
                    line = line .. getTile(x,y) .. " ";
                end
            end
            console.log(line);
        end
    end

    -- TODO: Remove. Draw the player's position.
	gui.drawText(10,30,"Position: (" .. playerX .. ", " .. playerY .. ")",0xFFFFFFFF,16);
    gui.drawText(10,60,"Page:" .. memory.readbyte(ADDRESS_PAGE),0xFFFFFFFF,16);

    -- Advance the frame
    emu.frameadvance();
end

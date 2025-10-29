-- Import RAM addresses
local ADDRESS_TILES = 0x0500;   -- The tile array/matrix
local ADDRESS_SCREEN = 0x006D;  -- The current screen within the level
local ADDRESS_HPOS = 0x0086;    -- The players horizontal position (in the current screen)
local ADDRESS_VPOS = 0x03B8;    -- The players vertical position

-- How wide and tall a RAM screen section is in tiles
local SCREEN_HEIGHT = 13;
local SCREEN_WIDTH = 32;

-- The size of each tile in pixels
local TILE_WIDTH = 8;

-- Keys that are currently being pressed
local k1;

-- Checks what keys are currently being pressed
function checkInputs()
    local inputs = input.get()
    k1 = inputs["Insert"]
end

-- Draw the player's global world position to the screen. 
function drawPlayerPosition()
    -- Get the player's x and y position in the world.
    local xPos = memory.read_u8(ADDRESS_HPOS) + (SCREEN_WIDTH*TILE_WIDTH)*memory.read_u8(ADDRESS_SCREEN);
    local yPos = memory.read_u8(ADDRESS_VPOS);

    -- Draw the player's position.
	local text = "Position: (" .. xPos .. ", " .. yPos .. ")";
	gui.drawText(10,30,text,0xFFFFFFFF,16);
end

-- Will print all of the RAM associated with tiles. (Prints the world). 
function printScreen()
    -- Clear the console.
    console.clear()

    -- Get all of the RAM associated with tiles.
    local level = memory.read_bytes_as_array(ADDRESS_TILES, SCREEN_WIDTH*SCREEN_HEIGHT);

    -- Prints the array in a human readable format.
    for y=1,SCREEN_HEIGHT do
        local line = ""
        for x=1,SCREEN_WIDTH/2 do
            if(x == playerH) then line = line .. " ***" else
                line = line .. " " .. string.format("%3x", level[(y-1)*(SCREEN_WIDTH/2) + x])
            end
        end
        for x=1,SCREEN_WIDTH/2 do
            line = line .. " " .. string.format("%3x", level[(y-1+SCREEN_HEIGHT)*(SCREEN_WIDTH/2) + x])
        end
        console.log(line)
    end
end

while true do
    -- Done every frame
	emu.frameadvance();
    checkInputs();

    -- Draw/Print useful data
	drawPlayerPosition();
    if(k1) then printScreen() end
    
end

---- CONSTANT VARIABLES

-- Important RAM addresses
local ADDRESS_TILES = 0x0500;   -- Array<int>*   : The tile array/matrix
local ADDRESS_SCREEN = 0x006D;  -- int*          : The current screen within the level
local ADDRESS_HPOS = 0x0086;    -- int*          : The players horizontal position (in the current screen)
local ADDRESS_VPOS = 0x03B8;    -- int*          : The players vertical position

-- How wide and tall a RAM screen section is in tiles
local SCREEN_HEIGHT = 13;
local SCREEN_WIDTH = 32;

-- The size of each tile in pixels
local TILE_WIDTH = 8;



---- SCRIPT VARIABLES

-- table<string, boolean> : Keys that are currently being pressed
local inputs;

-- int, int : The player's global world position
local playerX, playerY;



---- UTILITY FUNCTIONS

-- Get the player's position
function getPlayerPosition()
    -- Get the player's x and y position in the world.

    -- Calculated as (screen position + screen_width*number_of_screens_cleared)
    playerX = memory.readbyte(ADDRESS_HPOS) + (SCREEN_WIDTH*TILE_WIDTH)*memory.readbyte(ADDRESS_SCREEN);
    
    -- Calcualted as (screen position + mario_height)
    playerY = memory.readbyte(ADDRESS_VPOS) + 2*TILE_WIDTH;
end



---- MAIN GAME LOOP

while true do
    -- Get the inputs every frame
    inputs = input.get()

    -- Draw/Print useful data
    getPlayerPosition();


    -- TODO: Remove Debug Statement
    if(inputs["Insert"]) then 
        print("[DEBUG]:");
    end

    -- TODO: Remove. Draw the player's position.
	gui.drawText(10,30,"Position: (" .. playerX .. ", " .. playerY .. ")",0xFFFFFFFF,16);

    -- Advance the frame
    emu.frameadvance();
end

local ADDRESS_XPOS = 0x54;
local ADDRESS_YPOS = 0x58;
local ADDRESS_LIVES = 0xE9;

function drawPlayerPosition()
	local xPos = memory.read_u8(ADDRESS_XPOS);
	local yPos = memory.read_u8(ADDRESS_YPOS);

	local text = "Position: (" .. xPos .. ", " .. yPos .. ")";
	gui.drawText(10,10,text,0xFFFFFFFF,16);
end


memory.writea_u8(ADDRESS_LIVES, 99);

while true do
	emu.frameadvance();
	drawPlayerPosition();
end

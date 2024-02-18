program Pikoban;

{*
    https://www.onlinespiele-sammlung.de/sokoban/sokobangames/robsy/
    https://opengameart.org/content/top-sci-fi-cga-tileset
    https://www.bing.com/images/create
    https://fontmeme.com/pixel-fonts/
    https://github.com/tebe6502/Mad-Pascal
    https://fujinet.pl/neo6502/neo6502.html
    https://www.neo6502.com/
    convert.py by Bocianu
*}

//------------------------------------------------------------------------------

uses crt, neo6502;

//------------------------------------------------------------------------------

const
    ASS_GFX       = 'pikoban.gfx';
    ASS_EMPTY_PAL = 'pikoban_empty';
    ASS_TITLE_PAL = 'pikoban_title';
    ASS_TITLE_BMP = 'pikoban_title';
    ASS_WIN_PAL   = 'pikoban_winner';
    ASS_WIN_BMP   = 'pikoban_winner';
    JOY_LEFT      = %000001;
    JOY_RIGHT     = %000010;
    JOY_UP        = %000100;
    JOY_DOWN      = %001000;
    JOY_A         = %010000;
    JOY_B         = %100000;
    JOY_B_LEFT    = %100001;
    JOY_B_RIGHT   = %100010;
    JOY_DELAY     = 7;
    HEIGHT        = 8;
    WIDTH         = 8;
    BOARD_SIZE    = HEIGHT * WIDTH;
    CENTER_X      = 96;
    CENTER_Y      = 64;
    PLAYER_X      = CENTER_X + 8;
    PLAYER_Y      = CENTER_Y + 8;
    SET_SIZE      = 99;                 // count from ZERO
    TILE_SIZE     = 16;
    TILE_ADDRESS  = $300;               // BOARD_SIZE + 3 bytes of tiles header
    COMPLETE_LV   = $400;
    BOARD_ADDRESS = TILE_ADDRESS + 3;
    BUF           = $1000;              // $1000 - $7FFF, size: $8000

//------------------------------------------------------------------------------

{$i levels.inc}

//------------------------------------------------------------------------------

var
    tiles                 : array [0..(BOARD_SIZE + 2)] of byte absolute TILE_ADDRESS;
    board                 : array [0..WIDTH - 1, 0..HEIGHT - 1] of byte  absolute BOARD_ADDRESS;
    completed             : array [0..SET_SIZE] of byte absolute COMPLETE_LV;
    joy, joyDelay, lv     : byte;
    tmpB1, tmpB2, crates  : byte;
    gameMove, gamePush    : word;
    playerX, playerY      : byte;
    posX, posY, tmpW      : word;
    tmap                  : TTileMapHeader absolute TILE_ADDRESS;
    buffer                : array[0..0] of byte absolute BUF;

//------------------------------------------------------------------------------

function LoadPalette(fname :Tstring):boolean;
var
  w :word;
  b :byte;
begin
    fname := concat(fname,'.pal');
    NeoLoad(fname, BUF);
    result := NeoMessage.error = 0;
    if result then begin
      w := 0;
      for b := 0 to 255 do begin
        NeoSetPalette(b, buffer[w], buffer[w + 1], buffer[w + 2]);
        inc(w,3);
      end;
    end;
end;

//------------------------------------------------------------------------------

procedure LoadImage(fname:TString);
var
    x, o      :word;
    y, c      :byte;
    chunkname :TString;
begin
    c := 0; y := 0; x := 0;
    repeat
        str(c, chunkname);
        chunkname := concat('.c', chunkname);
        chunkname := concat(fname, chunkname);
        NeoLoad(chunkname, BUF);
        o := 0;
        repeat
            NeoSetColor(0, buffer[o], 0, 0, 0);
            NeoDrawPixel(x, y);
            inc(x); inc(o);
            if x=320 then begin
              x:=0; inc(y);
            end;
        until (y = 240) or (o = $8000);
        inc(c);
    until y = 240
end;

//------------------------------------------------------------------------------

procedure stop; inline;
begin
    repeat until false;
end;

//------------------------------------------------------------------------------

procedure debugInfo;
begin
    GotoXY(0,29); write('X: ', playerX + 1);
    GotoXY(0,30); write('Y: ', playerY + 1);
    tmpB1 := board[playerY, playerX - 1];
    GotoXY(43,27); write('left  : ', tmpB1, ' ');
    tmpB1 := board[playerY, playerX + 1];
    GotoXY(43,28); write('right : ', tmpB1, ' ');
    tmpB1 := board[playerY - 1, playerX];
    GotoXY(43,29); write('up    : ', tmpB1, ' ');
    tmpB1 := board[playerY + 1, playerX];
    GotoXY(43,30); write('down  : ', tmpB1, ' ');
end;

//------------------------------------------------------------------------------

procedure initBoard;
begin
    gameMove := 0;
    gamePush := 0;

    tmpW := BOARD_SIZE * lv;
    Move(LEVELS + tmpW, pointer(TILE_ADDRESS + 3), BOARD_SIZE);
    for tmpB1 := 0 to BOARD_SIZE - 1 do begin
        tmpB2 := peek(TILE_ADDRESS + 3 + tmpB1);
        if tmpB2 > 13 then begin
            posX := PLAYER_X + (tmpB1 mod HEIGHT) * TILE_SIZE;
            posY := PLAYER_Y + (tmpB1 div WIDTH) * TILE_SIZE;
        end
    end;

    crates := 0;
    for tmpB1 := 0 to BOARD_SIZE - 1 do begin
        tmpW := BOARD_ADDRESS + tmpB1;
        tmpB2 := peek(tmpW);
        if tmpB2 > 13 then begin
            if tmpB2 = T_PLAYER   then poke(tmpW, T_FLOOR);
            if tmpB2 = T_PLAYER_D then poke(tmpW, T_DECK);
            playerX := tmpB1 mod HEIGHT;
            playerY := tmpB1 div WIDTH;
            posX := PLAYER_X + playerX * TILE_SIZE;
            posY := PLAYER_Y + playerY * TILE_SIZE;
        end;
        if (tmpB2 = T_CRATE) then inc(crates);
    end;

    NeoWaitForVblank;
    NeoDrawTileMap(CENTER_X, CENTER_Y, CENTER_X + WIDTH * TILE_SIZE, CENTER_Y + HEIGHT * TILE_SIZE);
    NeoUpdateSprite(0, posX, posY, 0, 0, 0);

    GotoXY(0,1);   write('move   :', gameMove, '    ');
    GotoXY(0,2);   write('push   :', gamePush, '    ');
    GotoXY(0,3);   write('crates :', crates,   ' ');
    GotoXY(23,7);  write('level:'  , lv,       ' ');

    GotoXY(23,26); write('         ');
    GotoXY(23,26); if completed[lv] = 1 then write('completed');


end;

//------------------------------------------------------------------------------

procedure movePlayer(dir: byte);
var
    tmpX1, tmpY1, tmpX2, tmpY2: byte;
begin
    tmpX1 := playerX;
    tmpX2 := playerX;
    tmpY1 := playerY;
    tmpY2 := playerY;

    case dir of
        JOY_LEFT  : begin
            dec(tmpX1);
            dec(tmpX2,2);
        end;
        JOY_RIGHT : begin
            inc(tmpX1);
            inc(tmpX2,2);
        end;
        JOY_UP    : begin
            dec(tmpY1);
            dec(tmpY2,2);
        end;
        JOY_DOWN  : begin
            inc(tmpY1);
            inc(tmpY2,2);
        end;
    end;

    if board[tmpY1, tmpX1] < T_WALL then begin
        tmpB1 := board[tmpY1, tmpX1];
        tmpB2 := board[tmpY2, tmpX2];

        if (tmpB2 = T_FLOOR) or (tmpB2 = T_DECK) then begin
            if (tmpB1 = T_CRATE) and (tmpB2 = T_FLOOR) then begin
                board[tmpY1, tmpX1] := T_FLOOR;
                board[tmpY2, tmpX2] := T_CRATE;
                inc(gamePush);
            end;
            if (tmpB1 = T_CRATE) and (tmpB2 = T_DECK) then begin
                board[tmpY1, tmpX1] := T_FLOOR;
                board[tmpY2, tmpX2] := T_CRATE_D;
                dec(crates);
                inc(gamePush);
            end;
            if (tmpB1 = T_CRATE_D) and (tmpB2 = T_DECK) then begin
                board[tmpY1, tmpX1] := T_DECK;
                board[tmpY2, tmpX2] := T_CRATE_D;
                inc(gamePush);
            end;
            if (tmpB1 = T_CRATE_D) and (tmpB2 = T_FLOOR) then begin
                board[tmpY1, tmpX1] := T_DECK;
                board[tmpY2, tmpX2] := T_CRATE;
                inc(crates);
                inc(gamePush);
            end;
        end;

        if ((tmpB1 >= T_CRATE) and ((tmpB2 >= T_CRATE) or (tmpB2 >= T_WALL))) = false then
        begin
            case dir of
                JOY_LEFT  : begin dec(posX, TILE_SIZE); dec(playerX) end;
                JOY_RIGHT : begin inc(posX, TILE_SIZE); inc(playerX) end;
                JOY_UP    : begin dec(posY, TILE_SIZE); dec(playerY) end;
                JOY_DOWN  : begin inc(posY, TILE_SIZE); inc(playerY) end;
            end;
            inc(gameMove);
        end;
    end;
end;

//------------------------------------------------------------------------------

procedure titleScreen;
begin
    NeoWaitForVblank;
    TextBackground(0);
    TextColor(7);
    clrscr;

    LoadPalette(ASS_EMPTY_PAL);
    NeoSetColor(2,2,1,0,0);
    NeoDrawRect(0, 0, 6, 7 * 34);
    GotoXY(22,30); write('loading...');

    LoadImage(ASS_TITLE_BMP);
    NeoWaitForVblank;
    LoadPalette(ASS_TITLE_PAL);

    repeat until keypressed
end;

//------------------------------------------------------------------------------

procedure winnerScreen;
begin
    NeoWaitForVblank;
    NeoHideSprite(0);
    TextBackground(0);
    TextColor(7);
    clrscr;

    LoadPalette(ASS_EMPTY_PAL);
    NeoSetColor(2,2,1,0,0);
    NeoDrawRect(0, 0, 6, 7 * 34);
    GotoXY(22,30); write('loading...');

    LoadImage(ASS_WIN_BMP);
    NeoWaitForVblank;
    LoadPalette(ASS_WIN_PAL);

    stop;
end;


//------------------------------------------------------------------------------

procedure levelUp;
begin
    if lv < SET_SIZE then inc(lv) else lv := 0;
    initBoard;
end;

//------------------------------------------------------------------------------

procedure levelDown;
begin
    if lv > 0 then dec(lv) else lv := SET_SIZE;
    initBoard;
end;

//------------------------------------------------------------------------------

begin
    titleScreen;

    fillbyte(completed, 256, 0);
    NeoLoad(ASS_GFX, NEO_GFX_RAM);

    NeoWaitForVblank;
    NeoResetPalette;
    NeoResetSprites;
    TextBackground(10);
    TextColor(7);
    //NeoSetColor(2,2,0,0,0);
    clrscr;

    lv := 0;

    tmap.format := 1;
    tmap.width  := WIDTH;
    tmap.height := HEIGHT;

    posX := PLAYER_X + 3 * TILE_SIZE;
    posY := PLAYER_Y + 3 * TILE_SIZE;

    Move(LEVELS, pointer(TILE_ADDRESS + 3), BOARD_SIZE);
    NeoSelectTileMap(TILE_ADDRESS, 0, 0);

    initBoard;
    //debugInfo;

    GotoXY(0,28); write('Use controller to move.');
    GotoXY(0,29); write('Press BUTTON A to reset the level.');
    GotoXY(0,30); write('Press BUTTON B + LEFT or RIGHT to change the level.');

    repeat
        NeoWaitForVblank;

        joy := NeoGetJoy(1);
        if joyDelay > 0 then Dec(joyDelay);
        if (joyDelay = 0) and (joy <> 0) then begin

            case (joy and %111111) of
                JOY_LEFT    : movePlayer(JOY_LEFT);
                JOY_RIGHT   : movePlayer(JOY_RIGHT);
                JOY_UP      : movePlayer(JOY_UP);
                JOY_DOWN    : movePlayer(JOY_DOWN);
                JOY_A       : initBoard;
                JOY_B_RIGHT : levelUp;
                JOY_B_LEFT  : levelDown;
            end;
            joyDelay := JOY_DELAY;

            //debugInfo;

            NeoDrawTileMap(CENTER_X, CENTER_Y, CENTER_X + WIDTH * TILE_SIZE, CENTER_Y + HEIGHT * TILE_SIZE);
            NeoUpdateSprite(0, posX, posY, 0, 0, 0);
            GotoXY(9,1); write(gameMove, '    ');
            GotoXY(9,2); write(gamePush, '    ');
            GotoXY(9,3); write(crates,   '    ');

            if crates = 0 then begin
                completed[lv] := 1;
                NeoWaitForVblank;
                NeoUpdateSprite(0, posX, posY, 1, 0, 0);
                for tmpB1 := 1 to 90 do NeoWaitForVblank;

                //fillbyte(completed, SET_SIZE + 1, 1);
                tmpB2 := 0;
                for tmpB1 := 0 to SET_SIZE do
                    if completed[tmpB1] = 1 then inc(tmpB2);

                if tmpB2 = (SET_SIZE + 1) then winnerScreen;

                levelUp;
            end;
        end;
    until false;
end.

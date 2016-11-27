{ --------------------------------------------------------------------------
  Raspberry Pi I2C HD44780 LCD library
  Requires the the rpiio library.

  Designed for use with LCDs based on the PCF8574 IO expander, which may or
  may not have working backlight control via a transistor.
  This is also designed for 5x8 dot displays only currently.

  Copyright (c) Michael Nixon 2016.
  Distributed under the MIT license, please see the LICENSE file.
  -------------------------------------------------------------------------- }
unit rpii2clcdhd44780;

interface

uses baseunix, sysutils, classes, rpii2c;

const
  { PCF8574A I2C module addresses, depending on which address pins are
    pulled low. Most HD44780 I2C "backpack" modules I see expose A0, A1 and A2
    and there are 2 variants of the chip (PCF8574 and PCF8574A). The constants
    below are supplied for both chip variants. DEFAULT is with all the address
    lines pulled HIGH. Pick the constant for the chip variant you have, and the
    A0/A1/A2 pads you have shorted together. }
    
  HDLCD_PCF8574_ADDR_DEFAULT = $27;
  HDLCD_PCF8574_ADDR_A0 = $26;
  HDLCD_PCF8574_ADDR_A1 = $25;
  HDLCD_PCF8574_ADDR_A0A1 = $24;
  HDLCD_PCF8574_ADDR_A2 = $23;
  HDLCD_PCF8574_ADDR_A0A2 = $22;
  HDLCD_PCF8574_ADDR_A1A2 = $21;
  HDLCD_PCF8574_ADDR_A0A1A2 = $20;
  
  HDLCD_PCF8574A_ADDR_DEFAULT = $3F;
  HDLCD_PCF8574A_ADDR_A0 = $3E;
  HDLCD_PCF8574A_ADDR_A1 = $3D;
  HDLCD_PCF8574A_ADDR_A0A1 = $3C;
  HDLCD_PCF8574A_ADDR_A2 = $3B;
  HDLCD_PCF8574A_ADDR_A0A2 = $3A;
  HDLCD_PCF8574A_ADDR_A1A2 = $39;
  HDLCD_PCF8574A_ADDR_A0A1A2 = $38;

  { HD44780 commands }
  HDLCD_CLEARDISPLAY = $01;   { Clear all display contents }
  HDLCD_RETURNHOME = $02;     { Move cursor to 0,0 and reset display shift }
  HDLCD_ENTRYMODESET = $04;   { Sets cursor movement direction and display shift mode }
  HDLCD_DISPLAYCONTROL = $08; { Display on/off, cursor on/off, cursor blink on/off }
  HDLCD_CURSORSHIFT = $10;    { Move cursor and shift display without changing DDRAM }
  HDLCD_FUNCTIONSET = $20;    { Set LCD operating mode (bus type etc) }
  HDLCD_SETCGRAMADDR = $40;   { Set CGRAM address }
  HDLCD_SETDDRAMADDR = $80;   { Set DDRAM address }

  { HD44780 flags for display entry mode }
  HDLCD_ENTRYLEFT = $02;      { Increment DDRAM address when writing or reading }
  HDLCD_ENTRYRIGHT = $00;     { Decrement DDRAM address when writing or reading }
  HDLCD_ENTRYSHIFTON = $01;   { shift display when writing }
  HDLCD_ENTRYSHIFTOFF = $00;  { Do not shift display when writing }

  { HD44780 flags for display on/off control }
  HDLCD_DISPLAYON = $04;                    { Turn the display on }
  HDLCD_DISPLAYOFF = not HDLCD_DISPLAYON;   { Turn the display off }
  HDLCD_CURSORON = $02;                     { Turn the cursor on }
  HDLCD_CURSOROFF = not HDLCD_CURSORON;     { Turn the cursor off }
  HDLCD_BLINKON = $01;                      { Cursor will blink }
  HDLCD_BLINKOFF = not HDLCD_BLINKON;       { Cursor will not blink }

  { HD44780 flags for display and cursor shift }
  HDLCD_DISPLAYMOVE = $08;
  HDLCD_CURSORMOVE = $00;
  HDLCD_MOVELEFT = $00;
  HDLCD_MOVERIGHT = $04;

  { HD44780 function set flags }
  HDLCD_8BITMODE = $10;       { Use 8 bit mode for communications }
  HDLCD_4BITMODE = $00;       { Use 4 bit mode for communications }
  HDLCD_2LINE = $08;          { 2 line (and 4 line 20x4) displays }
  HDLCD_1LINE = $00;          { Single line display (not supported here) }
  HDLCD_5x10DOTS = $04;       { 5x10 dot mode (rare) }
  HDLCD_5x8DOTS = $00;        { 5x8 dot mode (most displays use this) }

  HDLCD_CGRAM_LENGTH = 64;    { Size of CGRAM, in bytes }

  { Specific to I2C PCF8574 adaptor boards in 4-bit mode }
  HDLCD_PCF8574_RS = $01;     { Register/data select (set = data) }
  HDLCD_PCF8574_RW = $02;     { Read/write direction (set = read) }
  HDLCD_PCF8574_EN = $04;     { Enable (strobe) line }
  HDLCD_PCF8574_BL = $08;     { Backlight enable (set = on ) }

type
  { Types of HD44780 displays supported }
  eHD44780LCDType = (eHD44780_2LINE16COL, eHD44780_4LINE20COL);

  { HD44780 LCD driver for displays sitting behind an I2C PCF8574 based driver }
  tHD44780LCDI2C = class(tobject)
    private
      i2cHandle: cint;                                { I2C device handle }
      backlightState: byte;                           { TRUE if the backlight is on }
      displayType: eHD44780LCDType;                   { Type of display }
      displayWidth: longint;                          { Width of the display in characters }
      displayHeight: longint;                         { Height of the display in characters }
      lineOffset: array[0..3] of byte;                { DDRAM offsets for each line }
      cgRAM: array[0..HDLCD_CGRAM_LENGTH] of byte;    { CGRAM contents for custom characters }
      onOffFlags: byte;                               { Current state of on/off flags }

      { These throw exceptions to make the callers simpler }
      procedure write8BitsAs4Bits(val: byte; rs: byte);
      procedure strobeData(val: byte);
      procedure writeCommand(command: byte);
      procedure writeData(val: byte);
      procedure writeCGRAM(start, length: longint);
    protected
    public
      constructor Create(i2cDevice: cint);
      destructor Destroy; override;

      function initialiseDisplay(backlight: boolean; dispType: eHD44780LCDType): boolean;
      function clearDisplay: boolean;

      function setBacklight(backlight: boolean): boolean;
      function setDisplay(displayOn: boolean): boolean;
      function SetCursor(enabled: boolean; blinking: boolean): boolean;

      function setPos(x, y: longint): boolean;
      function writeString(s: ansistring): boolean;
      function writeStringAtLine(s: ansistring; lineNumber: longint): boolean;

      function setCustomChar(charIndex: longint; charData: array of byte): boolean;
      function setAllCustomChars(charData: array of byte): boolean;
  end;

implementation

const
  HDLCD_EXCEPTION_NOHANDLE = 'tHD44780LCDI2C driver: No display handle set';
  HDLCD_EXCEPTION_ACCESS = 'tHD44780LCDI2C driver: Unable to access I2C device';

{ --------------------------------------------------------------------------
  -------------------------------------------------------------------------- }

{ --------------------------------------------------------------------------
  Write to the displays CGRAM, starting at <start>, and write <length>
  bytes. Copies them from self.cgRAM.
  -------------------------------------------------------------------------- }
procedure tHD44780LCDI2C.writeCGRAM(start, length: longint);
var
  i: longint;
begin
  self.writeCommand(HDLCD_SETCGRAMADDR or start);
  for i := start to start + (length - 1) do begin
    self.writeData(self.cgRAM[i]);
  end;
end;

{ --------------------------------------------------------------------------
  Set one custom character from <charData> (into CGRAM).
  <charIndex> is the character from 0-7 to write to.
  <charData> is an array of 8 bytes (1 per row) of character data.

  Row ordering is from top to bottom, the bottom row ideally should be $00
  otherwise it looks like a custor.
  A set bit means pixel on, an unset bit means pixel off. The 5 LSB bits are
  used, the upper 3 bits are not used.

  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.setCustomChar(charIndex: longint; charData: array of byte): boolean;
begin
  if (length(charData) <> 8) or (charIndex < 0) or (charIndex > 7) then begin
    result := false;
    exit;
  end;
  move(charData[0], self.cgRAM[charIndex shl 3], 8);
  try
    self.writeCGRAM(charindex shl 3, 8);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Set all custom characters at once from <charData> (into CGRAM).
  <charData> must be 64 bytes in length. Every 8 bytes is a character.

  Row ordering is from top to bottom, the bottom row ideally should be $00
  otherwise it looks like a custor.
  A set bit means pixel on, an unset bit means pixel off. The 5 LSB bits are
  used, the upper 3 bits are not used.

  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.setAllCustomChars(charData: array of byte): boolean;
begin
  if length(charData) <> HDLCD_CGRAM_LENGTH then begin
    result := false;
    exit;
  end;
  move(charData[0], self.cgRAM[0], HDLCD_CGRAM_LENGTH);
  try
    self.writeCGRAM(0, HDLCD_CGRAM_LENGTH);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Set the display state (on or off).
  <displayOn>: True to enable the display, false to disable it. When "off",
             memory contents are maintained. This does not really save
             any power, you can still see the LCD elements being strobed,
             it is just a way to hide the information on the display. Maybe
             the original, real HD44780 controller IC did stop strobing the
             LCD elements, but I only have clone chip modules.

  NOTE: Does not affect the backlight control on supported display modules.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.setDisplay(displayOn: boolean): boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;
  if displayOn then begin
    self.onOffFlags := self.onOffFlags or HDLCD_DISPLAYON;
  end else begin
    self.onOffFlags := self.onOffFlags and HDLCD_DISPLAYOFF;
  end;
  try
    self.writeCommand(HDLCD_DISPLAYCONTROL or self.onOffFlags);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Set the cursor state
  <enabled>: True to show the cursor
  <blinking>: True to make the cursor blink
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.SetCursor(enabled: boolean; blinking: boolean): boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;
  if enabled then begin
    self.onOffFlags := self.onOffFlags or HDLCD_CURSORON;
  end else begin
    self.onOffFlags := self.onOffFlags and HDLCD_CURSOROFF;
  end;
  if blinking then begin
    self.onOffFlags := self.onOffFlags or HDLCD_BLINKON;
  end else begin
    self.onOffFlags := self.onOffFlags and HDLCD_BLINKOFF;
  end;
  try
    self.writeCommand(HDLCD_DISPLAYCONTROL or self.onOffFlags);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Move the cursor to position X, Y on the LCD display.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.setPos(x, y: longint): boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;
  if (x < 0) or (x >= self.displayWidth) then begin
    result := false;
    exit;
  end;
  if (y < 0) or (y >= self.displayHeight) then begin
    result := false;
    exit;
  end;
  try
    self.writeCommand(HDLCD_SETDDRAMADDR or (self.lineOffset[y] + x));
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Write a string at the current location.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.writeString(s: ansistring): boolean;
var
  i: longint;
begin
  result := false;
  if self.i2cHandle < 1 then begin
    exit;
  end;
  try
    for i := 1 to length(s) do begin
      self.writeData(ord(s[i]));
    end;
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Write the string <s> at line <lineNumber>.
  Lines are numbered from 0 to the display height.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.writeStringAtLine(s: ansistring; lineNumber: longint): boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;
  if self.setPos(0, lineNumber) then begin
    result := self.writeString(s);
  end else begin
    result := false;
    exit;
  end;
end;

{ --------------------------------------------------------------------------
  Set the backlight state. TRUE = on, FALSE = off.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.setBacklight(backlight: boolean): boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;

  if backlight then begin
    self.backlightState := HDLCD_PCF8574_BL;
  end else begin
    self.backlightState := 0;
  end;

  try
    { Immediately set the new backlight state, we will only toggle that pin }
    result := i2cWrite(self.i2cHandle, self.backlightState);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Clear the display and reset the cursor to the home position.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.clearDisplay: boolean;
begin
  if self.i2cHandle < 1 then begin
    result := false;
    exit;
  end;
  try
    self.writeCommand(HDLCD_CLEARDISPLAY);
    { The datasheet does not define an execution time for CLEARDISPLAY.
      We will be safe and assume 10ms extra }
    sleep(10);

    self.writeCommand(HDLCD_RETURNHOME);
    { Extra time should be given for RETURNHOME, as per datasheet }
    sleep(2);
    result := true;
  except
    result := false;
  end;
end;

{ --------------------------------------------------------------------------
  Write 8 bits of data to the LCD (with the backlight flag) as 4 bits.
  <rs> should be 0 or set to HDLCD_PCF8574_RS for data (instead of command)
  Raises an exception on failure.
  -------------------------------------------------------------------------- }
procedure tHD44780LCDI2C.write8BitsAs4Bits(val: byte; rs: byte);
var
  byte1, byte2, flags: byte;
begin
  flags := rs or self.backlightState;
  if self.i2cHandle < 1 then begin
    raise exception.create(HDLCD_EXCEPTION_NOHANDLE);
  end;

  byte1 := (val and $F0) or flags;
  byte2 := ((val shl 4) and $F0) or flags;

  self.strobeData(byte1);
  self.strobeData(byte2);
end;

{ --------------------------------------------------------------------------
  Actually write <val> to the display, toggling the strobe line.
  Raises an exception on failure.
  -------------------------------------------------------------------------- }
procedure tHD44780LCDI2C.strobeData(val: byte);
begin
  if self.i2cHandle < 1 then begin
    raise exception.create(HDLCD_EXCEPTION_NOHANDLE);
  end;

  { For each write, we must do the following:
    - Initially put the data on the bus so the display has time to see it
    - Pull up EN to latch the data for a small delay (we do not need to wait
      for 1ms, but that is the best we can do without using high performance
      timing and eating CPU, and we do not need to write much data so it does
      not metter)
    - Pull down EN to finish the transfer, and wait for for the display to
      finish processing the command. 1ms is enough time to finish almost any
      command with exceptions, which are dealt with in other methods }

  { Put the data on the bus }
  if not i2cWrite(self.i2cHandle, val) then begin
    raise exception.create(HDLCD_EXCEPTION_ACCESS);
  end;

  { No delay needed here, by now the data is there. Tell the display to latch }
  if not i2cWrite(self.i2cHandle, val or HDLCD_PCF8574_EN) then begin
    raise exception.create(HDLCD_EXCEPTION_ACCESS);
  end;
  { Give the display some time to latch. As mentioned earlier, this could be
    replaced with a much smaller time delay. }
  sleep(1);

  { Unlatch the display }
  if not i2cWrite(self.i2cHandle, val) then begin
    raise exception.create(HDLCD_EXCEPTION_ACCESS);
  end;
  { Give the display time to process the data }
  sleep(1);
end;

{ --------------------------------------------------------------------------
  Write a command to the LCD.
  Raises an exception on failure.
  -------------------------------------------------------------------------- }
procedure tHD44780LCDI2C.writeCommand(command: byte);
begin
  if self.i2cHandle < 1 then begin
    raise exception.create(HDLCD_EXCEPTION_NOHANDLE);
  end;
  self.write8BitsAs4Bits(command, 0);
end;

{ --------------------------------------------------------------------------
  Write data to the LCD.
  Raises an exception on failure.
  -------------------------------------------------------------------------- }
procedure tHD44780LCDI2C.writeData(val: byte);
begin
  if self.i2cHandle < 1 then begin
    raise exception.create(HDLCD_EXCEPTION_NOHANDLE);
  end;
  self.write8BitsAs4Bits(val, HDLCD_PCF8574_RS);
end;

{ --------------------------------------------------------------------------
  Initialise the display, with the backlight set to a default state.
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function tHD44780LCDI2C.InitialiseDisplay(backlight: boolean; dispType: eHD44780LCDType): boolean;
begin
  try
    { Set the initial backlight state, so we don't turn it on by accident
      during initialisation if this is unwanted }
    if backlight then begin
      self.backlightState := HDLCD_PCF8574_BL;
    end else begin
      self.backlightState := 0;
    end;

    self.displayType := dispType;

    case self.displayType of
      eHD44780_2LINE16COL: begin
        self.displayWidth := 16;
        self.displayHeight := 2;
        self.lineOffset[0] := $00;
        self.lineOffset[1] := $16;
      end;
      eHD44780_4LINE20COL: begin
        self.displayWidth := 20;
        self.displayHeight := 4;
        self.lineOffset[0] := $00;
        self.lineOffset[1] := $40;
        self.lineOffset[2] := $14;
        self.lineOffset[3] := $54;
      end;
    else
      { Unsupported display type }
      result := false;
      exit;
    end;

    { Reset the LCD (wake up). It has an internal reset, but if VCC is too low
      this internal reset fails, so this is recommended (see datasheet) }

    { First wait 15ms. By the time this code is executing this should have
      already been met, but it does not hurt. }
    sleep(15);
    self.writeCommand($03);
    sleep(5);
    self.writeCommand($03);
    { No sleep needed here as the built in command latching sleep is enough,
      but the datasheet says 100 microseconds }
    self.writeCommand($03);
    self.writeCommand($02);

    { The below delay may be a little excessive but is there for clone displays
      that may require it. }
    sleep(64);

    { Now initialise it }
    { 2 line mode is required even for 4 line displays, as they are really just
      2 line displays with the 2 lines split in half. The common I2C interface
      board always uses 4-bit mode with other bits on the PCF8574 used for other
      purposes such as backlight control }

    self.onOffFlags := HDLCD_DISPLAYON;
    self.writeCommand(HDLCD_FUNCTIONSET or HDLCD_2LINE or HDLCD_5x8DOTS or HDLCD_4BITMODE);
    self.writeCommand(HDLCD_DISPLAYCONTROL or self.onOffFlags);
    self.writeCommand(HDLCD_ENTRYMODESET or HDLCD_ENTRYLEFT);

    { Moved the CLEARDISPLAY command - now just call our own function that
      also makes sure the cursor and shift are in a sane position }
    result := self.clearDisplay;
  except
    result := false;
    exit;
  end;

  result := true;
end;

{ --------------------------------------------------------------------------
  Class constructor
  -------------------------------------------------------------------------- }
constructor tHD44780LCDI2C.Create(i2cDevice: cint);
begin
  inherited Create;
  self.i2cHandle := i2cDevice;
  fillbyte(self.cgRAM[0], HDLCD_CGRAM_LENGTH, 0);
end;

{ --------------------------------------------------------------------------
  Class destructor
  -------------------------------------------------------------------------- }
destructor tHD44780LCDI2C.Destroy;
begin
  if self.i2cHandle > 0 then begin
    i2cClose(i2cHandle);
  end;
  inherited Destroy;
end;

end.

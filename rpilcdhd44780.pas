{ --------------------------------------------------------------------------
  Raspberry Pi LCD driver for:
    - HD44780 LCD display variants

  Requires the the rpiio library - https://github.com/zipplet/rpiio

  Supported display sizes / types:

    - 20x4 - fully tested
    - 16x2 - fully tested
    - 40x2 - untested, should work


  I2C displays:

  Designed for use with LCDs based on the PCF8574 IO expander, which may or
  may not have working backlight control via a transistor.
  This is also designed for 5x8 dot displays only currently.
  
  The PCF8574 IO expander is connected to the HD44780 as follows:
  
  PCF8574 D0 --> HD44780 RS (high = command, low = data)
  PCF8574 D1 --> HD44780 R/W (high = read, low = write)
  PCF8574 D2 --> HD44780 E (high = latch, low = process)
  PCF8574 D3 --> Backlight transistor on most modules (high = on, low = off)*
  PCF8574 D4 --> HD44780 DB0
  PCF8574 D5 --> HD44780 DB1
  PCF8574 D6 --> HD44780 DB2
  PCF8574 D7 --> HD44780 DB3
  
  The display is driven in 4-bit mode.
  
  *: There is usually a jumper pin on the back of modules that have a
     backlight transistor. This must be in place to turn on the backlight.


  Directly connected displays:

  TODO


  rpilcd daemon:

  TODO


  Copyright (c) Michael Nixon 2016.
  Distributed under the MIT license, please see the LICENSE file.
  -------------------------------------------------------------------------- }
unit rpilcdhd44780;

interface

uses baseunix, sysutils, classes, rpii2c;

const
  { PCF8574A I2C module addresses, depending on which address pins are
    pulled low. Most HD44780 I2C "backpack" modules I see expose A0, A1 and A2
    and there are 2 variants of the chip (PCF8574 and PCF8574A). The constants
    below are supplied for both chip variants. DEFAULT is with all the address
    lines pulled HIGH. Pick the constant for the chip variant you have, and the
    A0/A1/A2 pads you have shorted together. These are for NXP chips; other
    brands may use other addresses! }
    
  HD44780_PCF8574_ADDR_DEFAULT = $27;
  HD44780_PCF8574_ADDR_A0 = $26;
  HD44780_PCF8574_ADDR_A1 = $25;
  HD44780_PCF8574_ADDR_A0A1 = $24;
  HD44780_PCF8574_ADDR_A2 = $23;
  HD44780_PCF8574_ADDR_A0A2 = $22;
  HD44780_PCF8574_ADDR_A1A2 = $21;
  HD44780_PCF8574_ADDR_A0A1A2 = $20;
  
  HD44780_PCF8574A_ADDR_DEFAULT = $3F;
  HD44780_PCF8574A_ADDR_A0 = $3E;
  HD44780_PCF8574A_ADDR_A1 = $3D;
  HD44780_PCF8574A_ADDR_A0A1 = $3C;
  HD44780_PCF8574A_ADDR_A2 = $3B;
  HD44780_PCF8574A_ADDR_A0A2 = $3A;
  HD44780_PCF8574A_ADDR_A1A2 = $39;
  HD44780_PCF8574A_ADDR_A0A1A2 = $38;

  { Others }
  HD44780_CGRAM_LENGTH = 64;    { Size of CGRAM, in bytes }

type
  { Types of HD44780 displays supported }
  eHD44780LCDType = (eHD44780_2LINE16COL,
                     eHD44780_2LINE40COL,
                     eHD44780_4LINE20COL);

  { Initial display parameters when initialising the display }
  rHD44780InitParams = record
    lcdType: eHD44780LCDType;
    i2cDevice: trpiI2CDevice;
    backlightOn: boolean;
    displayOn: boolean;
    { Todo: Add flags for non I2C mode, such as pin mappings and 4/8 bit mode }
  end;

  { HD44780 LCD driver base class }
  trpilcdHD44780Base = class(tobject)
    private
    protected
      backlightState: byte;                           { Backlight state byte }
      displayType: eHD44780LCDType;                   { Type of display }
      displayWidth: longint;                          { Width of the display in characters }
      displayHeight: longint;                         { Height of the display in characters }
      lineOffset: array[0..3] of byte;                { DDRAM offsets for each line }
      cgRAM: array[0..HD44780_CGRAM_LENGTH] of byte;  { CGRAM contents for custom characters }
      onOffFlags: byte;                               { Current state of on/off flags }
      initialised: boolean;                           { True if the display has been initialised }

      procedure writeCommand(command: byte); virtual; abstract;
      procedure writeData(val: byte); virtual; abstract;

      procedure writeCGRAM(start, length: longint);
    public
      constructor Create; virtual;
      destructor Destroy; override;

      procedure initialiseDisplay(initialState: rHD44780InitParams); virtual;
      procedure clearDisplay;

      procedure setBacklight(backlight: boolean); virtual; abstract;
      procedure setDisplay(displayOn: boolean);
      procedure SetCursor(enabled: boolean; blinking: boolean);

      procedure setPos(x, y: longint);
      procedure writeString(s: ansistring);
      procedure writeStringAtLine(s: ansistring; lineNumber: longint);

      procedure setCustomChar(charIndex: longint; charData: array of byte);
      procedure setAllCustomChars(charData: array of byte);
  end;


  { HD44780 LCD driver for displays sitting behind an I2C PCF8574 IO expander
    wired in the manner described at the beginning of this unit }
  trpilcdHD44780I2C = class(trpilcdHD44780Base)
    private
      i2cDevice: trpiI2CDevice;                       { I2C device object }
    protected
      procedure write8BitsAs4Bits(val: byte; rs: byte);
      procedure strobeData(val: byte);

      procedure writeCommand(command: byte); override;
      procedure writeData(val: byte); override;
    public
      constructor Create; override;

      procedure initialiseDisplay(initialState: rHD44780InitParams); override;
      procedure setBacklight(backlight: boolean); override;
  end;

implementation

const
  { Exception messages }
  HD44780_EXCEPTION_PREFIX = 'rpilcdhd44780 driver: ';
  HD44780_EXCEPTION_NOHANDLE = HD44780_EXCEPTION_PREFIX + 'Display not initialised';
  HD44780_EXCEPTION_NOI2CHANDLE = HD44780_EXCEPTION_PREFIX + 'Invalid I2C object handle';
  HD44780_EXCEPTION_ALREADYINIT = HD44780_EXCEPTION_PREFIX + 'Display already initialised';
  HD44780_EXCEPTION_ACCESS = HD44780_EXCEPTION_PREFIX + 'Unable to access display';
  HD44780_EXCEPTION_BADPOS = HD44780_EXCEPTION_PREFIX + 'Bad x or y offset';
  HD44780_EXCEPTION_BADDATALEN = HD44780_EXCEPTION_PREFIX + 'Data length invalid';
  HD44780_EXCEPTION_BADCHARINDEX = HD44780_EXCEPTION_PREFIX + 'Bad custom character index';
  HD44780_EXCEPTION_DISPLAYUNSUPPORTED = HD44780_EXCEPTION_PREFIX + 'Unsupported display';
  HD44780_EXCEPTION_BACKLIGHTNOPIN = HD44780_EXCEPTION_PREFIX + 'Backlight control pin not set';

  { HD44780 general commands }
  HD44780_CLEARDISPLAY = $01;   { Clear all display contents }
  HD44780_RETURNHOME = $02;     { Move cursor to 0,0 and reset display shift }
  HD44780_ENTRYMODESET = $04;   { Sets cursor movement direction and display shift mode }
  HD44780_DISPLAYCONTROL = $08; { Display on/off, cursor on/off, cursor blink on/off }
  HD44780_CURSORSHIFT = $10;    { Move cursor and shift display without changing DDRAM }
  HD44780_FUNCTIONSET = $20;    { Set LCD operating mode (bus type etc) }
  HD44780_SETCGRAMADDR = $40;   { Set CGRAM address }
  HD44780_SETDDRAMADDR = $80; 	{ Set DDRAM address }

  { Flags for HD44780_ENTRYMODESET }
  HD44780_ENTRYLEFT = $02;      { Increment DDRAM address when writing or reading }
  HD44780_ENTRYRIGHT = $00;     { Decrement DDRAM address when writing or reading }
  HD44780_ENTRYSHIFTON = $01;   { Shift display when writing }
  HD44780_ENTRYSHIFTOFF = $00;  { Do not shift display when writing }

  { Flags for HD44780_DISPLAYCONTROL }
  HD44780_DISPLAYON = $04;                    	{ Turn the display on }
  HD44780_DISPLAYOFF = not HD44780_DISPLAYON;   { Turn the display off }
  HD44780_CURSORON = $02;                     	{ Turn the cursor on }
  HD44780_CURSOROFF = not HD44780_CURSORON;     { Turn the cursor off }
  HD44780_BLINKON = $01;                      	{ The cursor will blink }
  HD44780_BLINKOFF = not HD44780_BLINKON;       { The cursor will not blink }

  { Flags for HD44780_CURSORSHIFT }
  HD44780_DISPLAYMOVE = $08;
  HD44780_CURSORMOVE = $00;
  HD44780_MOVELEFT = $00;
  HD44780_MOVERIGHT = $04;

  { Flags for HD44780_FUNCTIONSET }
  HD44780_8BITMODE = $10;       { Use 8 bit mode for communications }
  HD44780_4BITMODE = $00;       { Use 4 bit mode for communications }
  HD44780_2LINE = $08;          { 2 line (and 4 line 20x4) displays }
  HD44780_1LINE = $00;          { Single line display (not supported here) }
  HD44780_5x10DOTS = $04;       { 5x10 dot mode (rare) }
  HD44780_5x8DOTS = $00;        { 5x8 dot mode (most displays use this) }

  { Specific to I2C PCF8574 adaptor boards }
  HD44780_PCF8574_RS = $01;     { Register/data select (set = data) }
  HD44780_PCF8574_RW = $02;     { Read/write direction (set = read) }
  HD44780_PCF8574_EN = $04;     { Latch data (set = latch) }
  HD44780_PCF8574_BL = $08;     { Backlight transistor (set = on ) }

{ --------------------------------------------------------------------------
  -------------------------------------------------------------------------- }

{ --------------------------------------------------------------------------
  Write to the displays CGRAM, starting at <start>, and write <length>
  bytes. Copies them from self.cgRAM.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.writeCGRAM(start, length: longint);
var
  i: longint;
begin
  self.writeCommand(HD44780_SETCGRAMADDR or start);
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

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.setCustomChar(charIndex: longint; charData: array of byte);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  if (length(charData) <> 8) or (charIndex < 0) or (charIndex > 7) then begin
    raise exception.create(HD44780_EXCEPTION_BADCHARINDEX);
  end;
  move(charData[0], self.cgRAM[charIndex shl 3], 8);
  self.writeCGRAM(charindex shl 3, 8);
end;

{ --------------------------------------------------------------------------
  Set all custom characters at once from <charData> (into CGRAM).
  <charData> must be 64 bytes in length. Every 8 bytes is a character.

  Row ordering is from top to bottom, the bottom row ideally should be $00
  otherwise it looks like a custor.
  A set bit means pixel on, an unset bit means pixel off. The 5 LSB bits are
  used, the upper 3 bits are not used.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.setAllCustomChars(charData: array of byte);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  if length(charData) <> HD44780_CGRAM_LENGTH then begin
    raise exception.create(HD44780_EXCEPTION_BADDATALEN);
  end;
  move(charData[0], self.cgRAM[0], HD44780_CGRAM_LENGTH);
  self.writeCGRAM(0, HD44780_CGRAM_LENGTH);
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

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.setDisplay(displayOn: boolean);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  if displayOn then begin
    self.onOffFlags := self.onOffFlags or HD44780_DISPLAYON;
  end else begin
    self.onOffFlags := self.onOffFlags and HD44780_DISPLAYOFF;
  end;
  self.writeCommand(HD44780_DISPLAYCONTROL or self.onOffFlags);
end;

{ --------------------------------------------------------------------------
  Set the cursor state.
  <enabled>: True to show the cursor
  <blinking>: True to make the cursor blink

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.SetCursor(enabled: boolean; blinking: boolean);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  if enabled then begin
    self.onOffFlags := self.onOffFlags or HD44780_CURSORON;
  end else begin
    self.onOffFlags := self.onOffFlags and HD44780_CURSOROFF;
  end;
  if blinking then begin
    self.onOffFlags := self.onOffFlags or HD44780_BLINKON;
  end else begin
    self.onOffFlags := self.onOffFlags and HD44780_BLINKOFF;
  end;
  self.writeCommand(HD44780_DISPLAYCONTROL or self.onOffFlags);
end;

{ --------------------------------------------------------------------------
  Move the cursor to position X, Y on the LCD display. Offsets are 0 based.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.setPos(x, y: longint);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  if (x < 0) or (x >= self.displayWidth) then begin
    raise exception.create(HD44780_EXCEPTION_BADPOS);
  end;
  if (y < 0) or (y >= self.displayHeight) then begin
    raise exception.create(HD44780_EXCEPTION_BADPOS);
  end;
  self.writeCommand(HD44780_SETDDRAMADDR or (self.lineOffset[y] + x));
end;

{ --------------------------------------------------------------------------
  Write a string at the current location.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.writeString(s: ansistring);
var
  i: longint;
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  for i := 1 to length(s) do begin
    self.writeData(ord(s[i]));
  end;
end;

{ --------------------------------------------------------------------------
  Write the string <s> at line <lineNumber>.
  Line offsets begin at 0.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.writeStringAtLine(s: ansistring; lineNumber: longint);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;
  self.setPos(0, lineNumber);
  self.writeString(s);
end;

{ --------------------------------------------------------------------------
  Set the backlight state. TRUE = on, FALSE = off.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.setBacklight(backlight: boolean);
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;

  if backlight then begin
    self.backlightState := HD44780_PCF8574_BL;
  end else begin
    self.backlightState := 0;
  end;

  try
    { Immediately set the new backlight state, we will only toggle that pin }
    self.i2cDevice.writeByte(self.backlightState);
  except
    on e: exception do begin
      raise exception.create(HD44780_EXCEPTION_ACCESS + ': ' + e.message);
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Clear the display and reset the cursor to the home position.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.clearDisplay;
begin
  if not self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_NOHANDLE);
  end;

  self.writeCommand(HD44780_CLEARDISPLAY);
  { The datasheet does not define an execution time for CLEARDISPLAY.
    We will be safe and assume 10ms extra }
  sleep(10);

  self.writeCommand(HD44780_RETURNHOME);
  { Extra time should be given for RETURNHOME, as per datasheet }
  sleep(2);
end;

{ --------------------------------------------------------------------------
  Write 8 bits of data to the LCD (with the backlight flag) as 4 bits.
  <rs> should be 0 or set to HD44780_PCF8574_RS for data (instead of command)

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.write8BitsAs4Bits(val: byte; rs: byte);
var
  byte1, byte2, flags: byte;
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(HD44780_EXCEPTION_NOI2CHANDLE);
  end;

  flags := rs or self.backlightState;
  byte1 := (val and $F0) or flags;
  byte2 := ((val shl 4) and $F0) or flags;

  self.strobeData(byte1);
  self.strobeData(byte2);
end;

{ --------------------------------------------------------------------------
  Write <val> to the display, toggling the strobe line.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.strobeData(val: byte);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(HD44780_EXCEPTION_NOI2CHANDLE);
  end;

  { For each write, we must do the following:
    - Initially put the data on the bus so the display has time to see it
    - Pull up EN to latch the data for a small delay (we do not need to wait
      for 1ms, but that is the best we can do without using high performance
      timing and eating CPU, and we do not need to write much data so it does
      not matter)
    - Pull down EN to finish the transfer, and wait for for the display to
      finish processing the command. 1ms is enough time to finish almost any
      command with exceptions, which are dealt with in other methods }

  try
    { Put the data on the bus }
    self.i2cDevice.writeByte(val);

    { No delay needed here, by now the data is there. Tell the display to latch }
    self.i2cDevice.writeByte(val or HD44780_PCF8574_EN);

    { Give the display some time to latch. As mentioned earlier, this could be
      replaced with a much smaller time delay. }
    //sleep(1);

    { Unlatch the display }
    self.i2cDevice.writeByte(val);

    { Give the display time to process the data }
    //sleep(1);
  except
    on e: exception do begin
      raise exception.create(HD44780_EXCEPTION_ACCESS + ': ' + e.message);
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Write a command to the LCD.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.writeCommand(command: byte);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(HD44780_EXCEPTION_NOI2CHANDLE);
  end;

  self.write8BitsAs4Bits(command, 0);
end;

{ --------------------------------------------------------------------------
  Write data to the LCD.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.writeData(val: byte);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(HD44780_EXCEPTION_NOI2CHANDLE);
  end;

  self.write8BitsAs4Bits(val, HD44780_PCF8574_RS);
end;

{ --------------------------------------------------------------------------
  Extra code needed for I2C initialisation.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780I2C.initialiseDisplay(initialState: rHD44780InitParams);
begin
  { Not a duplicate check; without this the user could be naughty and call
    this to change the I2C device }
  if self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_ALREADYINIT);
  end;
  if not assigned(initialState.i2cDevice) then begin
    raise exception.create(HD44780_EXCEPTION_NOI2CHANDLE);
  end;
  self.i2cDevice := initialState.i2cDevice;

  inherited initialiseDisplay(initialState);
end;

{ --------------------------------------------------------------------------
  Initialise the display, with the backlight set to a default state.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpilcdHD44780Base.initialiseDisplay(initialState: rHD44780InitParams);
begin
  if self.initialised then begin
    raise exception.create(HD44780_EXCEPTION_ALREADYINIT);
  end;

  { Set the initial backlight state, so we don't turn it on by accident
    during initialisation if this is unwanted. However all of the displays
    I have tested start with the backlight turned on anyway. }
  if initialState.backlightOn then begin
    { Yes, this is the I2C constant but that's OK }
    self.backlightState := HD44780_PCF8574_BL;
  end else begin
    self.backlightState := 0;
  end;

  self.displayType := initialState.lcdType;

  case self.displayType of
    eHD44780_2LINE16COL: begin
      self.displayWidth := 16;
      self.displayHeight := 2;
      self.lineOffset[0] := $00;
      self.lineOffset[1] := $40;
    end;
    eHD44780_2LINE40COL: begin
      self.displayWidth := 40;
      self.displayHeight := 2;
      self.lineOffset[0] := $00;
      self.lineOffset[1] := $40;
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
    { Unsupported display type (for now, I plan to add more if I can get them) }
    raise exception.create(HD44780_EXCEPTION_DISPLAYUNSUPPORTED);
  end;

  { Reset the LCD (wake up). It has an internal reset, but if VCC is too low
    this internal reset fails, so this is recommended (see datasheet) }

  { First wait 15ms. By the time this code is executing this should have
    already been met as the display was probably connected at poweron,
    but it does not hurt. }
  sleep(15);
  self.writeCommand($03);
  sleep(5);
  self.writeCommand($03);
  { No sleep needed here as the built in command latching sleep is enough,
    but the datasheet says 100 microseconds. }
  self.writeCommand($03);
  self.writeCommand($02);

  { The below delay may be a little excessive but is there for clone displays
    that may require it. }
  sleep(64);

  { Now the display is "awake" we can initialise it }
    
  { 2 line mode is required even for 4 line displays, as they are really just
    2 line displays with the 2 lines split in half. The common I2C interface
    board always uses 4-bit mode with other bits on the PCF8574 used for other
    purposes such as backlight control }

  self.onOffFlags := $00;
  if initialState.displayOn then begin
    self.onOffFlags := self.onOffFlags or HD44780_DISPLAYON;
  end;
  self.writeCommand(HD44780_FUNCTIONSET or HD44780_2LINE or HD44780_5x8DOTS or HD44780_4BITMODE);
  self.writeCommand(HD44780_DISPLAYCONTROL or self.onOffFlags);
  self.writeCommand(HD44780_ENTRYMODESET or HD44780_ENTRYLEFT);

  { Now we can consider the display to be initialised }
  self.initialised := true;

  { Moved the CLEARDISPLAY command - now just call our own function that
    also makes sure the cursor and shift are in a sane position }
  self.clearDisplay;

end;

{ --------------------------------------------------------------------------
  Base class constructor
  -------------------------------------------------------------------------- }
constructor trpilcdHD44780Base.Create;
begin
  inherited Create;
  fillbyte(self.cgRAM[0], HD44780_CGRAM_LENGTH, 0);
  self.initialised := false;
end;

{ --------------------------------------------------------------------------
  I2C class constructor
  -------------------------------------------------------------------------- }
constructor trpilcdHD44780I2C.Create;
begin
  inherited Create;
  self.i2cDevice := nil;
end;

{ --------------------------------------------------------------------------
  Base class destructor
  -------------------------------------------------------------------------- }
destructor trpilcdHD44780Base.Destroy;
begin
  self.initialised := false;
  inherited Destroy;
end;

end.

{ --------------------------------------------------------------------------
  Raspberry Pi OLED driver for:
    - SSD1306 I2C OLED 128x64 displays

  Requires the the rpiio library - https://github.com/zipplet/rpiio

  Copyright (c) Michael Nixon 2016.
  Distributed under the MIT license, please see the LICENSE file.
  -------------------------------------------------------------------------- }
unit rpilcdi2cssd1306;

interface

uses baseunix, sysutils, classes, rpii2c;

const
  { SSD1306 module addresses }
    
  LCD_SSD1306_ADDR_DEFAULT = $3c;

  { Control bytes }

  LCD_SSD1306_CONTROL_COMMAND = $80;    { Next byte is a command }
  LCD_SSD1306_CONTROL_DATA1BYTE = $40;  { Next byte is data }
  LCD_SSD1306_CONTROL_ALLDATA = $00;    { Data stream follows }

  { Initialisation commands }

  LCD_SSD1306_CMD_CHARGEPUMP_SET = $8d;
  LCD_SSD1306_CMD_CHARGEPUMP_ON = $14;
  { Must be followed by DISPLAYON }
  LCD_SSD1306_CMD_SETDISPLAYCLOCKDIV = $d5;
  LCD_SSD1306_CMD_SETMULTIPLEX = $a8;

  { Normal commands }

  LCD_SSD1306_CMD_SETCONTRAST = $81;
  LCD_SSD1306_CMD_DISPLAYON = $af;
  LCD_SSD1306_CMD_DISPLAYOFF = $ae;
  LCD_SSD1306_CMD_ALLPIXELSON = $a5;
  LCD_SSD1306_CMD_ALLPIXELSOFF = $a4;
  LCD_SSD1306_CMD_INVERSEON = $a7;
  LCD_SSD1306_CMD_INVERSEOFF = $a6;

  LCD_SSD1306_PIXEL_WIDTH = 128;        { Width in pixels }
  LCD_SSD1306_PIXEL_HEIGHT = 64;        { Height in pixels }
  LCD_SSD1306_PAGE_SIZE = 32;           { Number of bytes per page }
  LCD_SSD1306_GDDRAM_SIZE = 256;        { Size of GDDRAM in bytes }

type

  tSSD1306OLEDI2C = class(tobject)
    private
      i2cDevice: trpiI2CDevice;
      displayBuffer: array[0..LCD_SSD1306_GDDRAM_SIZE - 1] of byte;

      procedure writeDataByte(value: byte);
      procedure writeCommandByte(value: byte);
      procedure writeDataBytes(bytes: pointer; length: longint);
    protected
    public
      constructor Create(i2cDeviceObject: trpiI2CDevice);
      destructor Destroy; override;

      procedure initialiseDisplay;
      procedure setDisplay(onOrOff: boolean);
      procedure setContrast(level: byte);
      procedure setAllPixelsOn(enable: boolean);
      procedure setInverseMode(enable: boolean);
  end;

implementation

const
  LCD_EXCEPTION_PREFIX = 'rpilcdi2cssd1306 driver: ';
  LCD_EXCEPTION_NOHANDLE = LCD_EXCEPTION_PREFIX + 'I2C device object not set';
  LCD_EXCEPTION_ACCESS = LCD_EXCEPTION_PREFIX + 'Unable to access I2C device';

{ --------------------------------------------------------------------------
  -------------------------------------------------------------------------- }

{ --------------------------------------------------------------------------
  Invert all pixels on the display
  If <enable> is TRUE, GDDRAM bits will be interpreted as follows:
    - 1 = off
    - 0 = on

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.setInverseMode(enable: boolean);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;
  if enable then begin
    self.writeCommandByte(LCD_SSD1306_CMD_INVERSEON);
  end else begin
    self.writeCommandByte(LCD_SSD1306_CMD_INVERSEOFF);
  end;
end;

{ --------------------------------------------------------------------------
  Light all pixels on the display at once.
  If <enable> is TRUE, all pixels will be illuminated, otherwise GDDRAM
  contents will be displayed.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.setAllPixelsOn(enable: boolean);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;
  if enable then begin
    self.writeCommandByte(LCD_SSD1306_CMD_ALLPIXELSON);
  end else begin
    self.writeCommandByte(LCD_SSD1306_CMD_ALLPIXELSOFF);
  end;
end;

{ --------------------------------------------------------------------------
  Set the display contrast.
  <level> is the contrast level, from $00 to $ff.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.setContrast(level: byte);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;
  self.writeCommandByte(LCD_SSD1306_CMD_SETCONTRAST);
  self.writeCommandByte(level);
end;


{ --------------------------------------------------------------------------
  Turn the display on or off.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.setDisplay(onOrOff: boolean);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;
  if onOrOff then begin
    self.writeCommandByte(LCD_SSD1306_CMD_DISPLAYON);
  end else begin
    self.writeCommandByte(LCD_SSD1306_CMD_DISPLAYOFF);
  end;
end;

{ --------------------------------------------------------------------------
  Write 1 data byte to the display.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.writeDataByte(value: byte);
var
  buffer: array[0..1] of byte;
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;

  buffer[0] := LCD_SSD1306_CONTROL_DATA1BYTE;
  buffer[1] := value;

  self.i2cDevice.writeBytes(@buffer[0], 2);
end;

{ --------------------------------------------------------------------------
  Write a command byte to the display.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.writeCommandByte(value: byte);
var
  buffer: array[0..1] of byte;
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;

  buffer[0] := LCD_SSD1306_CONTROL_COMMAND;
  buffer[1] := value;

  self.i2cDevice.writeBytes(@buffer[0], 2);
end;

{ --------------------------------------------------------------------------
  Write multiple data bytes to the display.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.writeDataBytes(bytes: pointer; length: longint);
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;

  self.i2cDevice.writeByte(LCD_SSD1306_CONTROL_ALLDATA);
  self.i2cDevice.writeBytes(bytes, length);
end;

{ --------------------------------------------------------------------------
  Initialise the display, with the backlight set to a default state.

  Throws an exception on failure.
  -------------------------------------------------------------------------- }
procedure tSSD1306OLEDI2C.InitialiseDisplay;
begin
  if not assigned(self.i2cDevice) then begin
    raise exception.create(LCD_EXCEPTION_NOHANDLE);
  end;

  { Start with the display off }
  self.setDisplay(false);

  { Set the display clock divider to the suggested ratio, $80 }
  self.writeCommandByte(LCD_SSD1306_CMD_SETDISPLAYCLOCKDIV);
  self.writeCommandByte($80);

  { Setup multiplexer }
  self.writeCommandByte(LCD_SSD1306_CMD_SETMULTIPLEX);
  self.writeCommandByte(LCD_SSD1306_PIXEL_HEIGHT - 1);

  self.writeCommandByte(LCD_SSD1306_CMD_CHARGEPUMP_SET);
  self.writeCommandByte(LCD_SSD1306_CMD_CHARGEPUMP_ON);

  { Set Display Offset }
  self.writeCommandByte($d3);
  self.writeCommandByte($00);

  { Set Display Start Line }
  self.writeCommandByte($40);

  { Set Segment remap }
  self.writeCommandByte($a0 or $1);

  { Set COM output direction }
  self.writeCommandByte($c0);

  { Set COM pins hardware configuration }
  self.writeCommandByte($da);
  self.writeCommandByte($12);

  self.setContrast($cf);

  { SETPRECHARGE }
  self.writeCommandByte($d9);
  self.writeCommandByte($f1);

  self.setAllPixelsOn(false);
  self.setInverseMode(false);

  self.setDisplay(true);
end;

{ --------------------------------------------------------------------------
  Class constructor
  -------------------------------------------------------------------------- }
constructor tSSD1306OLEDI2C.Create(i2cDeviceObject: trpiI2CDevice);
begin
  inherited Create;
  self.i2cDevice := i2cDeviceObject;
end;

{ --------------------------------------------------------------------------
  Class destructor
  -------------------------------------------------------------------------- }
destructor tSSD1306OLEDI2C.Destroy;
begin
  {}
  inherited Destroy;
end;

end.

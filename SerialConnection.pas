program SerialConnection;

{$mode objfpc}{$H+}

{ Example GPS                                                 }
{                                                                              }
{ This example uses the serial (UART) device in the Raspberry Pi to connect    }
{ to another computer and echo back any line of text it receives.              }
{                                                                              }
{ You will need a serial cable or a USB to serial converter to connect the Pi  }
{ to your computer, the Pi uses pin 14 (Transmit) and pin 15 (Receive) as well }
{ as a Ground pin to make the connection. The documentation shows you where to }
{ find each of the pins on the Raspberry Pi.                                   }
{                                                                              }
{ Raspberry Pi Model A and B (26 pin header)                                   }
{   https://www.raspberrypi.org/documentation/usage/gpio/                      }
{                                                                              }
{ Raspberry Pi Models A+/B+/Zero/2B/3B (40 pin header)                         }
{   https://www.raspberrypi.org/documentation/usage/gpio-plus-and-raspi2/      }
{                                                                              }
{ You will also need a terminal program running on your computer, you can use  }
{ something like PuTTY to create a serial connection to the COM port you are   }
{ using. For this example we'll use these connection settings:                 }
{                                                                              }
{ Speed: 9600                                                                  }
{ Data Bits: 8                                                                 }
{ Stop Bits: 1                                                                 }
{ Parity: None                                                                 }
{ Flow Control: None                                                           }
{                                                                              }
{  To compile the example select Run, Compile (or Run, Build) from the menu.   }
{                                                                              }
{  Once compiled copy the kernel.img file to an SD card along with the firmware}
{  files and use it to boot your Raspberry Pi.                                 }
{                                                                              }
{  Raspberry Pi A/B/A+/B+/Zero version                                         }
{   What's the difference? See Project, Project Options, Config and Target.    }

{Declare some units used by this example.}
uses
  GlobalConst,
  GlobalTypes,
  Platform,
  FileSystem,
  FATFS,       {Include the FAT file system driver}
  MMC,         {Include the MMC/SD core to access our SD card}
  Threads,
  DateUtils,
  Dos,
  Classes,
  Console,
  Framebuffer,
  //BCM2835,
  //BCM2708,
  BCM2837,
  BCM2710,
  SysUtils,
  Serial;   {Include the Serial unit so we can open, read and write to the device}

{We'll need a window handle plus a couple of others.}
var
 Count:LongWord;
 Lines:LongWord;
 Fileno:LongWord;
 Character:Char;
 Characters:String;
 WindowHandle:TWindowHandle;

 Filename:String;
 //FileStream:TFileStream;

 Buffer:String;
 TempmemStream: TMemoryStream;
 fstemp: TFileStream;


 Procedure WriteLog(const LogText:String);
 begin
       Buffer:=LogText;
       TempmemStream.Seek(TempmemStream.Size,soFromBeginning);
       TempmemStream.WriteBuffer(Buffer[1],Length(Buffer));

 end;


 Procedure Logdata();
 begin
       //GetTime(Hour,Min,Sec,HSec);

       Filename:='C:\logs\gps_' + IntToStr(fileno) + '.txt';
       ConsoleWindowWriteLn(WindowHandle, 'Filename is ' + Filename);
       if FileExists(Filename) then
           begin
               ConsoleWindowWriteLn(WindowHandle, 'C:\logs\gps.txt exist' );
               fstemp := TFileStream.Create(Filename, fmOpenReadWrite);
           end
       else
           begin
               ConsoleWindowWriteLn(WindowHandle, 'C:\logs\gps.txt does not exist, making it');
                fstemp := TFileStream.Create(Filename, fmCreate);
           end;

       ConsoleWindowWriteLn(WindowHandle, 'MemoryStream size' + IntToStr(TempmemStream.Size));
       try
          if TempmemStream.Size>0 then
             begin
                 TempmemStream.Position:=0;
                 fstemp.CopyFrom(TempmemStream, TempmemStream.Size);
             end;

       finally
             fstemp.free;
       end;

       fileno:= fileno + 1;

 end;


begin
 {Create a console window at full size}
 WindowHandle:=ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_FULL,True);

 {Output some welcome text on the console window}
 ConsoleWindowWriteLn(WindowHandle,'Welcome to GPS tester');

 {We may need to wait a couple of seconds for any drive to be ready}
 ConsoleWindowWriteLn(WindowHandle,'Waiting for drive C:\');
 while not DirectoryExists('C:\') do
  begin
   {Sleep for a second}
   Sleep(1000);
  end;
 ConsoleWindowWriteLn(WindowHandle,'C:\ drive is ready');
 ConsoleWindowWriteLn(WindowHandle,'');

 {First we need to open the serial device and set the speed and other parameters.

  We can use the SerialOpen function in the Platform unit to open the default serial
  device or we can use the SerialDeviceOpen function in the Serial unit if we need
  to specify which device to open.

  We'll use SerialOpen and specify 9600 as the speed with 8 data bits, 1 stop bit,
  no parity and no flow control. The constants used here can be found in the GlobalConst
  unit.

  The last 2 parameters allow setting the size of the transmit and receive buffers,
  passing 0 means use the default size.}
 if SerialOpen(9600,SERIAL_DATA_8BIT,SERIAL_STOP_1BIT,SERIAL_PARITY_NONE,SERIAL_FLOW_NONE,0,0) = ERROR_SUCCESS then
  begin

   {Opened successfully, display a message}
   ConsoleWindowWriteLn(WindowHandle,'Serial device opened');

   TempmemStream := TMemoryStream.Create;

   //Count:=0;
   //Characters:='UBX-CFG-RATE 10000';
   //SerialWrite(@Character,SizeOf(Character),Count);

   {Setup our starting point}
   Count:=0;
   Lines:=0;
   fileno:=0;
   Characters:='';

   {Loop endlessly waiting for data}
   while True do
    begin
     {Read from the serial device using the SerialRead function, to be safe we
      would normally check the result of this function before using the value}

     SerialRead(@Character,SizeOf(Character),Count);

     {Check what character we received}
     if Character = #13 then
      begin
       {If we received a carriage return then write our characters to the console}
       ConsoleWindowWriteLn(WindowHandle, Characters);
       WriteLog(Characters);
       Lines:= Lines + 1;

       //{6 lines every 10 seconds,  save every 10 minutes}
       if Lines = 360 then
        begin
         Lines:=0;
         ConsoleWindowWriteLn(WindowHandle,'Saving data to log file');
         Logdata();

         //flush the memory
         TempmemStream.Clear();
         TempmemStream.Destroy();

         // make a new memory buffer
         TempmemStream := TMemoryStream.Create;

       end;

       {Add a carriage return and line feed}
       Characters:=Characters + Chr(13) + Chr(10);

       {And echo them back to the serial device using SerialWrite}
       SerialWrite(PChar(Characters),Length(Characters),Count);

       {Now clear the characters and wait for more}
       Characters:='';
      end
     else
      begin
       {Add the character to what we have already recevied}
       Characters:=Characters + Character;
      end;

     {No need to sleep on each loop, SerialRead will wait until data is received}
    end;



   {Close the serial device using SerialClose}
   SerialClose;

   ConsoleWindowWriteLn(WindowHandle,'Serial device closed');
  end
 else
  begin
   {Must have been an error, print a message on the console}
   ConsoleWindowWriteLn(WindowHandle,'An error occurred opening the serial device');
  end;

 {Halt the thread if we exit the loop}
 ThreadHalt(0);
end.


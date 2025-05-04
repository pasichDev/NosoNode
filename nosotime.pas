unit NosoTime;
{
  Nosotime 1.3
  20 вересня 2023 року
  Модуль часу Noso для синхронізації часу в проєкті Noso.
  Потребує пакету indy. (Завдання: видалити цю залежність)

  Зміни:
  - Випадкове використання серверів NTP.
  - Асинхронний процес обмежено кожні 5 секунд.
  - Функції, пов’язані з часом блоку.
  - Тестування NTP.

  TThreadUpdateOffset:
  - Клас потоку, який використовується для асинхронного оновлення зсуву часу.
  - Hosts: Рядок, що містить сервери NTP для використання.
  - Execute: Перевизначає логіку виконання потоку для виклику GetTimeOffset.

  GetNetworkTimestamp:
  - Отримує UNIX-мітку часу з вказаного сервера NTP.
  - Параметри:
    - hostname: Ім'я хоста сервера NTP.
  - Повертає: UNIX-мітку часу як int64 або 0 у разі помилки.

  TimestampToDate:
  - Перетворює UNIX-мітку часу у зручний для читання рядок дати.
  - Параметри:
    - timestamp: UNIX-мітка часу для перетворення.
  - Повертає: Рядкове представлення дати.

  GetTimeOffset:
  - Обчислює зсув часу, використовуючи випадковий сервер NTP зі списку.
  - Параметри:
    - NTPServers: Рядок імен хостів серверів NTP, розділених двокрапкою.
  - Повертає: Обчислений зсув часу як int64.

  UTCTime:
  - Отримує поточну UTC UNIX-мітку часу, скориговану на зсув часу.
  - Повертає: Скориговану UNIX-мітку часу як int64.

  UTCTimeStr:
  - Отримує поточну UTC UNIX-мітку часу у вигляді рядка для сумісності.
  - Повертає: Скориговану UNIX-мітку часу як рядок.

  UpdateOffset:
  - Ініціює асинхронне оновлення зсуву часу за допомогою потоку.
  - Параметри:
    - NTPServers: Рядок імен хостів серверів NTP, розділених двокрапкою.

  TimeSinceStamp:
  - Обчислює час, що минув з моменту заданої UNIX-мітки часу.
  - Параметри:
    - Lvalue: UNIX-мітка часу, з якої обчислюється минулий час.
  - Повертає: Рядок, що представляє минулий час у секундах, хвилинах, годинах, днях, місяцях або роках.

  BlockAge:
  - Обчислює поточний вік блоку на основі UTC часу.
  - Повертає: Вік блоку як ціле число.

  NextBlockTimeStamp:
  - Обчислює очікувану UNIX-мітку часу для наступного блоку.
  - Повертає: Мітку часу як int64.

  IsBlockOpen:
  - Визначає, чи знаходиться поточний блок у періоді операції.
  - Повертає: Логічне значення, яке вказує, чи відкритий блок.

  Змінні:
  - NosoT_TimeOffset: Поточний зсув часу як int64.
  - NosoT_LastServer: Останній використаний сервер NTP як рядок.
  - NosoT_LastUpdate: Час останнього оновлення як int64.

Nosotime 1.3
20 вересня 2023 року
Модуль часу Noso для синхронізації часу в проєкті Noso.
Потребує пакету indy. (Завдання: видалити цю залежність)

Зміни:
- Випадкове використання серверів NTP.
- Асинхронний процес обмежено кожні 5 секунд.
- Функції, пов’язані з часом блоку.
- Тестування NTP.
}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IdSNTP, DateUtils, strutils;

Type
   TThreadUpdateOffset = class(TThread)
   private
     Hosts: string;
   protected
     procedure Execute; override;
   public
     constructor Create(const CreatePaused: Boolean; const THosts:string);
   end;

Function GetNetworkTimestamp(hostname:string):int64;
function TimestampToDate(timestamp:int64):String;
Function GetTimeOffset(NTPServers:String):int64;
Function UTCTime:Int64;
Function UTCTimeStr:String;
Procedure UpdateOffset(NTPServers:String);
function TimeSinceStamp(Lvalue:int64):string;
Function BlockAge():integer;
Function NextBlockTimeStamp():Int64;
Function IsBlockOpen():boolean;

Var
  NosoT_TimeOffset : int64 = 0;
  NosoT_LastServer : string = '';
  NosoT_LastUpdate : int64 = 0;

IMPLEMENTATION

constructor TThreadUpdateOffset.Create(const CreatePaused: Boolean; const THosts:string);
begin
  inherited Create(CreatePaused);
  Hosts := THosts;
end;

procedure TThreadUpdateOffset.Execute;
Begin
  GetTimeOffset(Hosts);
End;

{Returns the data from the specified NTP server [Hostname]}
Function GetNetworkTimestamp(hostname:string):int64;
var
  NTPClient: TIdSNTP;
begin
result := 0;
NTPClient := TIdSNTP.Create(nil);
   TRY
   NTPClient.Host := hostname;
   NTPClient.Active := True;
   NTPClient.ReceiveTimeout:=500;
   result := DateTimeToUnix(NTPClient.DateTime);
   if result <0 then result := 0;
   EXCEPT on E:Exception do
      result := 0;
   END; {TRY}
NTPClient.Free;
end;

{Returns a UNIX timestamp in a human readeable format}
function TimestampToDate(timestamp:int64):String;
begin
result := DateTimeToStr(UnixToDateTime(TimeStamp));
end;

{
Uses a random NTP server from the list provided to set the value of the local variables.
NTPservers string must use NosoCFG format: server1:server2:server3:....serverX:
If directly invoked, will block the main thread until finish. (not recommended except on app launchs)
}
Function GetTimeOffset(NTPServers:String):int64;
var
  Counter    : integer = 0;
  ThisNTP    : int64;
  MyArray    : array of string;
  RanNumber : integer;
Begin
Result := 0;
NTPServers := StringReplace(NTPServers,':',' ',[rfReplaceAll, rfIgnoreCase]);
NTPServers := Trim(NTPServers);
MyArray := SplitString(NTPServers,' ');
Rannumber := Random(length(MyArray));
For Counter := 0 to length(MyArray)-1 do
   begin
   ThisNTP := GetNetworkTimestamp(MyArray[Rannumber]);
   if ThisNTP>0 then
      begin
      Result := ThisNTP - DateTimeToUnix(Now);
      NosoT_LastServer := MyArray[Rannumber];
      NosoT_LastUpdate := UTCTime;
      break;
      end;
   Inc(RanNumber);
   If RanNumber >= length(MyArray)-1 then RanNumber := 0;
   end;
NosoT_TimeOffset := Result;
End;

{Returns the UTC UNIX timestamp}
Function UTCTime:Int64;
Begin
Result := DateTimeToUnix(Now, False) +NosoT_TimeOffset;
End;

{Implemented for easy compatibility with nosowallet}
Function UTCTimeStr:String;
Begin
Result := InttoStr(DateTimeToUnix(Now, False) +NosoT_TimeOffset);
End;

{Implemented to allow an async update of the offset; can be called every 5 seconds max}
Procedure UpdateOffset(NTPServers:String);
const
  LastRun : int64 = 0;
var
  LThread : TThreadUpdateOffset;
Begin
if UTCTime <= LastRun+4 then exit;
LastRun := UTCTime;
LThread := TThreadUpdateOffset.Create(true,NTPservers);
LThread.FreeOnTerminate:=true;
LThread.Start;
End;

{Tool: returns a simple string with the time elapsed since the provided timestamp [LValue]}
function TimeSinceStamp(Lvalue:int64):string;
var
  Elapsed : Int64 = 0;
Begin
Elapsed := UTCTime - Lvalue;
if Elapsed div 60 < 1 then result := IntToStr(Elapsed)+'s'
else if Elapsed div 3600 < 1 then result := IntToStr(Elapsed div 60)+'m'
else if Elapsed div 86400 < 1 then result := IntToStr(Elapsed div 3600)+'h'
else if Elapsed div 2592000 < 1 then result := IntToStr(Elapsed div 86400)+'d'
else if Elapsed div 31536000 < 1 then result := IntToStr(Elapsed div 2592000)+'M'
else result := IntToStr(Elapsed div 31536000)+' Y';
end;

{Return the current block age}
Function BlockAge():integer;
Begin
Result := UTCtime mod 600;
End;

{Returns the expected timestamp for next block}
Function NextBlockTimeStamp():Int64;
var
  currTime : int64;
  Remains : int64;
Begin
CurrTime := UTCTime;
Remains := 600-(CurrTime mod 600);
Result := CurrTime+Remains;
End;

{Returns if the current block is in operation period}
Function IsBlockOpen():boolean;
Begin
result := true;
if ( (BlockAge<10) or (BlockAge>585) ) then result := false;
End;

END. // END UNIT


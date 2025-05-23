{
  Файл: mpsyscheck.pas
  Опис: Модуль для перевірки системних характеристик, таких як швидкість хешування, доступна пам'ять та швидкість завантаження.
  Автор: [Вкажіть автора]
  Дата створення: [Вкажіть дату]
  Ліцензія: [Вкажіть ліцензію]

  Опис модулю:
  Даний модуль містить функції для тестування продуктивності системи:
    - Sys_HashSpeed: Вимірює швидкість хешування SHA256 у багатопоточному режимі.
    - AllocateMem: Оцінює доступний обсяг оперативної пам'яті.
    - TestDownloadSpeed: Визначає швидкість завантаження даних з Інтернету.

  Опис класів та функцій:
  - TThreadHashtest: Клас потоку для тестування швидкості хешування.
      - Execute: Виконує 10 000 операцій хешування SHA256.
      - Create: Конструктор потоку.

  - Sys_HashSpeed(cores: integer = 4): int64
      Функція для вимірювання швидкості хешування SHA256 з використанням вказаної кількості ядер (потоків).
      Повертає кількість хешів за мілісекунду.

  - AllocateMem(UpToMb: integer = 1024): int64
      Функція для оцінки максимально доступної пам'яті (у мегабайтах).
      Для Windows та Unix реалізовано різні підходи.

  - TestDownloadSpeed(): int64
      Функція для тестування швидкості завантаження 1 МБ файлу з Інтернету.
      Повертає швидкість у байтах за мілісекунду.

  Змінні:
  - OpenHashThreads: Лічильник активних потоків хешування.

  Залежності:
    - Класи: TThread, TMemoryStream, TFPHttpClient
    - Модулі: Classes, SysUtils, fphttpclient, Linux (для Unix), nosodebug, nosocrypto

  Примітка:
    Для коректної роботи функцій необхідно підключити відповідні зовнішні модулі та бібліотеки.
}
unit mpSysCheck;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient{$IFDEF Unix} ,Linux {$ENDIF},nosodebug,
  nosocrypto;

Type
  TThreadHashtest = class(TThread)
    protected
      procedure Execute; override;
    public
      Constructor Create(CreateSuspended : boolean);
    end;

Function Sys_HashSpeed(cores:integer=4):int64;
Function AllocateMem(UpToMb:integer=1024):int64;
Function TestDownloadSpeed():int64;

var
  OpenHashThreads : integer;

implementation

constructor TThreadHashtest.Create(CreateSuspended : boolean);
Begin
  inherited Create(CreateSuspended);
End;

procedure TThreadHashtest.Execute;
var
  counter : integer;
Begin
for counter := 1 to 10000 do
   HashSha256String(IntToStr(counter));
Dec(OpenHashThreads);
End;

Function Sys_HashSpeed(cores:integer=4):int64;
var
  counter    : integer;
  StartTime, EndTime : int64;
  ThisThread : TThreadHashtest;
Begin
OpenHashThreads := cores;
for counter := 1 to cores do
   begin
   ThisThread := TThreadHashtest.Create(true);
   ThisThread.FreeOnTerminate:=true;
   ThisThread.Start;
   end;
StartTime := GetTickCount64;
Repeat
   sleep(1);
until OpenHashThreads=0;
EndTime := GetTickCount64;
Result := (cores*10000) div (EndTime-StartTime);
End;

Function AllocateMem(UpToMb:integer=1024):int64;
var
  h: TFPCHeapStatus;
  i: cardinal;
  LastHeapFails: boolean;
  Z: Pointer;
  {$IFDEF Unix} Info : TSysInfo; {$ENDIF}
Begin
result := 0;
{$IFDEF WINDOWS}
Result := 0;
LastHeapFails := ReturnNilIfGrowHeapFails;
ReturnNilIfGrowHeapFails := True;
for i := 1 to $FFFF do
begin
  Z := GetMem(i * $10000);
  if Z = nil then
    break;
  h := GetFPCHeapStatus;
  Result := h.MaxHeapSize div 1048576;
  Freemem(Z);
end;
ReturnNilIfGrowHeapFails := LastHeapFails;
{$ENDIF}
{$IFDEF Unix}
SysInfo(@Info);
result := Info.freeram div 1048576;
{$ENDIF}
End;

Function TestDownloadSpeed():int64;
var
  MS: TMemoryStream;
  DownLink : String = '';
  Conector : TFPHttpClient;
  Sucess   : boolean = false;
  timeStart, timeEnd : int64;
  trys     : integer = 0;
Begin
result := 0;
DownLink := 'https://raw.githubusercontent.com/nosocoin/NosoNode/main/1mb.dat';
MS := TMemoryStream.Create;
Conector := TFPHttpClient.Create(nil);
conector.ConnectTimeout:=1000;
conector.IOTimeout:=1000;
conector.AllowRedirect:=true;
REPEAT
timeStart := GetTickCount64;
   TRY
   Conector.Get(DownLink,MS);
   MS.SaveToFile('NOSODATA'+DirectorySeparator+'1mb.dat');
   timeEnd := GetTickCount64;
   //DeleteFile('NOSODATA'+DirectorySeparator+'1mb.dat');
   Sucess := true;
   EXCEPT ON E:Exception do
    ToLog('events',TimeToStr(now)+e.Message);
   END{Try};
Inc(Trys);
UNTIL ( (sucess) or (trys=5) );
MS.Free;
conector.free;
if Sucess then result := 1048576 div (TimeEnd-TimeStart);
End;

END. // END UNIT


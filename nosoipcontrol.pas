{
  /*
  Модуль: NosoIPControl

  Опис:
    Модуль призначений для контролю та обліку IP-адрес, які взаємодіють із системою.
    Забезпечує потокобезпечне додавання та очищення записів про IP-адреси.

  Типи:
    IPControl - структура для зберігання IP-адреси та кількості звернень з неї.

  Глобальні змінні:
    ArrCont      - динамічний масив записів IPControl.
    CS_ArrCont   - критична секція для захисту доступу до ArrCont.
    LastIPsClear - час останнього очищення масиву IP-адрес.

  Функції та процедури:
    Function AddIPControl(ThisIP:String):integer;
      - Додає або оновлює запис про IP-адресу. Якщо адреса вже існує, збільшує лічильник звернень.
        Повертає поточну кількість звернень з цієї IP-адреси.

    Procedure ClearIPControls();
      - Очищає масив IP-адрес та оновлює час останнього очищення.

  Ініціалізація:
    - Ініціалізує масив ArrCont та критичну секцію CS_ArrCont.

  Завершення:
    - Звільняє ресурси критичної секції CS_ArrCont.
  */
}
unit NosoIPControl;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, nosotime;

type
  IPControl = record
    IP : String;
    Count : integer;
  end;

Function AddIPControl(ThisIP:String):integer;
Procedure ClearIPControls();

var
  ArrCont      : Array of IPControl;
  CS_ArrCont   : TRTLCriticalSection;
  LastIPsClear : int64 = 0;

IMPLEMENTATION

Function AddIPControl(ThisIP:String):integer;
var
  counter : integer;
  Added : boolean = false;
Begin
  EnterCriticalSection(CS_ArrCont);
  For counter := 0 to length(ArrCont)-1 do
    begin
    if ArrCont[Counter].IP = ThisIP then
      begin
      Inc(ArrCont[Counter].count);
      Result := ArrCont[Counter].count;
      Added := true;
      Break
      end;
    end;
  if not added then
    begin
    Setlength(ArrCont,length(ArrCont)+1);
    ArrCont[length(ArrCont)-1].IP := thisIP;
    ArrCont[length(ArrCont)-1].count := 1;
    Result := 1;
    end;
  LeaveCriticalSection(CS_ArrCont);
End;

Procedure ClearIPControls();
Begin
  EnterCriticalSection(CS_ArrCont);
  Setlength(ArrCont,0);
  LeaveCriticalSection(CS_ArrCont);
  LAstIPsClear := UTCTime;
End;

INITIALIZATION
  SetLength(ArrCont,0);
  InitCriticalSection(CS_ArrCont);

FINALIZATION
  DoneCriticalSection(CS_ArrCont);

END.


unit nosomasternodes;

{$mode ObjFPC}{$H+}

{
  Файл: nosomasternodes.pas

  Опис:
  Даний модуль реалізує основну логіку роботи з мастернодами (masternodes) для блокчейн-проєкту Noso. 
  Він містить типи даних, процедури та функції для:
    - Зберігання та обробки списку мастернод,
    - Перевірки та валідації мастернод,
    - Роботи з файлами мастернод,
    - Організації багатопотокової перевірки вузлів,
    - Ведення обліку перевірок та віку мастернод,
    - Захисту даних за допомогою критичних секцій.

  Основні типи:
    - TMNode: структура для зберігання інформації про мастерноду (IP, порт, адреси, блоки, хеш тощо).
    - TMNCheck: структура для зберігання результату перевірки мастерноди.
    - TMNsData: структура для зберігання додаткових даних по мастерноді (IP:порт, адреса, вік).

  Основні процедури та функції:
    - SetMasternodesFilename: встановлює ім'я файлу для зберігання мастернод.
    - SetLocalIP, SetMN_Sign: встановлюють локальні параметри мастерноди.
    - GetMNReportString: формує рядок-звіт про мастерноду.
    - RunMNVerification: запускає багатопотокову перевірку мастернод.
    - GetMNsListLength, ClearMNsList: отримання та очищення списку мастернод.
    - IsLegitNewNode: перевіряє, чи є новий вузол легітимним.
    - CheckMNReport: обробляє звіт про мастерноду.
    - CreditMNVerifications: нараховує перевірки мастернодам.
    - Робота з файлами: LoadMNsFile, SaveMNsFile, SetMN_FileText, GetMN_FileText.
    - Робота з чергами очікування та отриманих мастернод.

  Особливості:
    - Для потокобезпечності використовуються критичні секції (TRTLCriticalSection).
    - Підтримується багатопотокова перевірка вузлів через TThreadMNVerificator.
    - Дані про мастерноди зберігаються у файлі та в оперативній пам'яті.
    - Передбачено механізми для унікальності IP, підрахунку віку, перевірки підписів та хешів.

  Призначення:
    Даний модуль є ядром для підтримки децентралізованої мережі мастернод у блокчейні Noso, 
    забезпечує їхню перевірку, збереження, синхронізацію та захист від дублювання чи підробки.

  Автор: (вкажіть автора)
  Ліцензія: (вкажіть ліцензію)
}

INTERFACE

uses
  Classes, SysUtils,IdTCPClient, IdGlobal,strutils,
  NosoDebug,NosoTime,NosoGeneral,nosocrypto,nosounit;

Type

  TThreadMNVerificator = class(TThread)
    private
      FSlot: Integer;
    protected
      procedure Execute; override;
    public
      constructor Create(const CreatePaused: Boolean; const ConexSlot:Integer);
    end;

  TMNode = Packed Record
    Ip           : string[15];
    Port         : integer;
    Sign         : string[40];
    Fund         : string[40];
    First        : integer;
    Last         : integer;
    Total        : integer;
    Validations  : integer;
    Hash         : String[32];
    end;

  TMNCheck = Record
    ValidatorIP  : string;
    Block        : integer;
    SignAddress  : string;
    PubKey       : string;
    ValidNodes   : string;
    Signature    : string;
    end;

  TMNsData  = Packed Record
    ipandport  : string;
    address    : string;
    age        : integer;
    end;

  Procedure SetMasternodesFilename(LText:String);

  Procedure SetLocalIP(NewValue:String);
  Procedure SetMN_Sign(SignAddress,lPublicKey,lPrivateKey:String);
  Function GetMNReportString(block:integer):String;
  Function VerifyThreadsCount:integer;
  function RunMNVerification(Block:integer;LocSynctus:String;LocalIP:String;publicK,privateK:String):String;

  Function GetMNsListLength():Integer;
  Procedure ClearMNsList();
  Function IsIPMNAlreadyProcessed(OrderText:string):Boolean;
  Procedure ClearMNIPProcessed();
  function IsMyMNListed(LocalIP:String):boolean;
  Function IsLegitNewNode(ThisNode:TMNode;block:integer):Boolean;
  Function CheckMNReport(LineText:String;block:integer):String;
  Function GetMNodeFromString(const StringData:String; out ToMNode:TMNode):Boolean;
  Function GetStringFromMN(Node:TMNode):String;
  Function FillMnsListArray(out LDataArray:TStringArray) : Boolean;
  Function GetMNsAddresses(Block:integer):String;
  Procedure CreditMNVerifications();

  Function GetMNsChecksCount():integer;
  Function GetValidNodesCountOnCheck(StringNodes:String):integer;
  Function GetMNCheckFromString(Linea:String):TMNCheck;
  Procedure ClearMNsChecks();
  Function MnsCheckExists(Ip:String):Boolean;
  Procedure AddMNCheck(ThisData:TMNCheck);
  Function GetStringFromMNCheck(Data:TMNCheck): String;
  Function IsMyMNCheckDone():Boolean;

  Procedure SetMNsHash();
  Function GetMNsHash():String;

  Function LengthReceivedMNs():Integer;
  Procedure ClearReceivedMNs();
  Function IsMNIPReceived(DataSource:String):boolean;

  Function LengthWaitingMNs():Integer;
  Procedure AddWaitingMNs(Linea:String);
  Function GetWaitingMNs():String;

  Function GetMNAgeCount(TNode:TMNode):string;
  Function LoadMNsFile():String;
  Procedure SaveMNsFile(GotText:string);
  Procedure SetMN_FileText(lvalue:String);
  Function GetMN_FileText():String;
  Procedure FillMNsArray(TValue:String);
  Function GetVerificatorsText():string;

var
  MasterNodesFilename : string= '';
  MNFileHandler       : textfile;
  CSMNsFile           : TRTLCriticalSection;

  MNsListCopy         : array of TMnode;
  CurrSynctus         : string;
  LocalMN_IP          : string = '';
  LocalMN_Port        : string = '8080';
  LocalMN_Sign        : string = '';
  LocalMN_Funds       : string = '';
  LocalMN_Public      : string = '';
  LocalMN_Private     : string = '';
  UnconfirmedIPs      : integer;

  MyMNsHash           : String = '';
  CS_MNsHash          : TRTLCriticalSection;

  VerifiedNodes       : String;
  CSVerNodes          : TRTLCriticalSection;

  OpenVerificators    : integer;
  CSVerifyThread      : TRTLCriticalSection;

  MNsList             : array of TMnode;
  CSMNsList           : TRTLCriticalSection;

  ArrayIPsProcessed   : array of string;
  CSMNsIPProc         : TRTLCriticalSection;

  ArrMNChecks         : array of TMNCheck;
  CSMNsChecks         : TRTLCriticalSection;

  ArrayMNsData        : array of TMNsData;

  MN_FileText         : String = '';
  CSMN_FileText       : TRTLCriticalSection;

  ArrWaitMNs          : array of String;
  CSWaitingMNs        : TRTLCriticalSection;

  ArrReceivedMNs      : array of String;
  CSReceivedMNs       : TRTLCriticalSection;

IMPLEMENTATION

Procedure SetMasternodesFilename(LText:String);
Begin
  MasterNodesFilename := LText;
  AssignFile(MNFileHandler,MasterNodesFilename);
  if not FileExists(MasterNodesFilename) then CreateEmptyFile(MasterNodesFilename);
  LoadMNsFile;
End;

Procedure SetLocalIP(NewValue:String);
Begin
  LocalMN_IP := NewValue;
End;

Procedure SetMN_Sign(SignAddress,lPublicKey,lPrivateKey:String);
Begin
  LocalMN_Sign    := SignAddress;
  LocalMN_Public  := lPublicKey;
  LocalMN_Private := lPrivateKey;
End;

// Returns the string to send the own MN report
Function GetMNReportString(block:integer):String;
Begin
  // {5}IP 6{Port} 7{SignAddress} 8{FundsAddress} 9{FirstBlock} 10{LastVerified}
  //    11{TotalVerified} 12{BlockVerifys} 13{hash}
  result := LocalMN_IP+' '+LocalMN_Port+' '+LocalMN_Sign+' '+LocalMN_Funds+' '+block.ToString+' '+block.ToString+' '+
  '0'+' '+'0'+' '+HashMD5String(LocalMN_IP+LocalMN_Port+LocalMN_Sign+LocalMN_Funds);
End;

{$REGION ThreadVerificator}

constructor TThreadMNVerificator.Create(const CreatePaused: Boolean; const ConexSlot:Integer);
begin
  inherited Create(CreatePaused);
  FSlot:= ConexSlot;
end;

procedure TThreadMNVerificator.Execute;
var
  TCPClient : TidTCPClient;
  Linea : String = '';
  WasPositive : Boolean;
  IP : string;
  Port: integer;
  Success : boolean ;
  Trys :integer = 0;
Begin
  AddNewOpenThread('VerifyMN '+FSlot.ToString,UTCTime);
  Sleep(1000);
  TRY {BIG}
    IP := MNsListCopy[FSlot].Ip;
    Port := MNsListCopy[FSlot].Port;
    TCPClient := TidTCPClient.Create(nil);
    TCPclient.Host:=Ip;
    TCPclient.Port:=Port;
    TCPclient.ConnectTimeout:= 1000;
    TCPclient.ReadTimeout:= 1000;
    REPEAT
      Inc(Trys);
      TRY
        TCPclient.Connect;
        TCPclient.IOHandler.WriteLn('MNVER');
        Linea := TCPclient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
        TCPclient.Disconnect();
        Success := true;
      EXCEPT on E:Exception do
        begin
        Success := false;
        end;
      END{try};
    UNTIL ((Success) or (trys = 3));
    TCPClient.Free;
    if success then
      begin
      WasPositive := StrToBoolDef(Parameter(Linea,0),false);
      if ( (WasPositive) and (Parameter(Linea,1)=CurrSynctus) ) then
        begin
        EnterCriticalSection(CSVerNodes);
        VerifiedNodes := VerifiedNodes+Ip+';'+Port.ToString+':';
        LeaveCriticalSection(CSVerNodes);
        end
      else if ( (WasPositive) and (Parameter(Linea,1)<>CurrSynctus) ) then
        begin
        // Wrong synctus returned
        end
      else
        begin
        // Was not possitive
        end;
      end;
    If Parameter(Linea,3) <> LocalMN_IP then Inc(UnconfirmedIPs);
  EXCEPT on E:Exception do
    begin
    ToLog('exceps',FormatDateTime('dd mm YYYY HH:MM:SS.zzz', Now)+' -> '+'CRITICAL MNs VERIFICATION ('+Ip+'): '+E.Message);
    end;
  END{BIG TRY};
  EnterCriticalSection(CSVerifyThread);
  Dec(OpenVerificators);
  LeaveCriticalSection(CSVerifyThread);
  CloseOpenThread('VerifyMN '+FSlot.ToString);
End;

Function VerifyThreadsCount:integer;
Begin
  EnterCriticalSection(CSVerifyThread);
  Result := OpenVerificators;
  LeaveCriticalSection(CSVerifyThread);
End;

{$ENDREGION ThreadVerificator}

function RunMNVerification(Block:integer;LocSynctus:String;LocalIP:String;publicK,privateK:String):String;
var
  counter : integer;
  ThisThread : TThreadMNVerificator;
  Launched : integer = 0;
  WaitCycles : integer = 0;
  DataLine : String;
Begin
  BeginPerformance('RunMNVerification');
  Result := '';
  CurrSynctus := LocSynctus;
  SetLocalIP(LocalIP);
  VerifiedNodes := '';
  setlength(MNsListCopy,0);
  EnterCriticalSection(CSMNsList);
  MNsListCopy := copy(MNsList,0,length(MNsList));
  LeaveCriticalSection(CSMNsList);
  UnconfirmedIPs := 0;
  for counter := 0 to length(MNsListCopy)-1 do
    begin
    if (( MNsListCopy[counter].ip <> LocalIP) and (IsValidIp(MNsListCopy[counter].ip)) ) then
      begin
      Inc(Launched);
      ThisThread := TThreadMNVerificator.Create(true,counter);
      ThisThread.FreeOnTerminate:=true;
      ThisThread.Start;
      end;
    end;
  EnterCriticalSection(CSVerifyThread);
  OpenVerificators := Launched;
  LeaveCriticalSection(CSVerifyThread);
  Repeat
    sleep(100);
    Inc(WaitCycles);
  until ( (VerifyThreadsCount= 0) or (WaitCycles = 250) );
  //ToDeepDeb(Format('MNs verification finish: %d launched, %d Open, %d cycles',[Launched,VerifyThreadsCount,WaitCycles ]));
  //ToDeepDeb(Format('Unconfirmed IPs: %d',[UnconfirmedIPs ]));
  if VerifyThreadsCount>0 then
    begin
    EnterCriticalSection(CSVerifyThread);
    OpenVerificators := 0;
    LeaveCriticalSection(CSVerifyThread);
    end;
  Result := LocalIP+' '+Block.ToString+' '+LocalMN_Sign+' '+publicK+' '+
            VerifiedNodes+' '+GetStringSigned(VerifiedNodes,privateK);
  EndPerformance('RunMNVerification');
End;

{$REGION MNsList handling}

// Returns the count of reported MNs
Function GetMNsListLength():Integer;
Begin
  EnterCriticalSection(CSMNsList);
  Result := Length(MNsList);
  LeaveCriticalSection(CSMNsList);
End;

Procedure ClearMNsList();
Begin
  EnterCriticalSection(CSMNsList);
  SetLength(MNsList,0);
  LeaveCriticalSection(CSMNsList);
  EnterCriticalSection(CSMNsIPProc);
  Setlength(ArrayIPsProcessed,0);
  LeaveCriticalSection(CSMNsIPProc);
End;

// Verify if an IP was already processed
Function IsIPMNAlreadyProcessed(OrderText:string):Boolean;
var
  ThisIP : string;
  counter : integer;
Begin
  result := false;
  ThisIP := parameter(OrderText,5);
  EnterCriticalSection(CSMNsIPProc);
  if length(ArrayIPsProcessed) > 0 then
    begin
    for counter := 0 to length(ArrayIPsProcessed)-1 do
      begin
      if ArrayIPsProcessed[counter] = ThisIP then
        begin
        result := true;
        break
        end;
      end;
    end;
  if result = false then Insert(ThisIP,ArrayIPsProcessed,length(ArrayIPsProcessed));
  LeaveCriticalSection(CSMNsIPProc);
End;

Procedure ClearMNIPProcessed();
Begin
  EnterCriticalSection(CSMNsIPProc);
  Setlength(ArrayIPsProcessed,0);
  LeaveCriticalSection(CSMNsIPProc);
End;

function IsMyMNListed(LocalIP:String):boolean;
var
  counter : integer;
Begin
  result := false;
  if GetMNsListLength > 0 then
    begin
    EnterCriticalSection(CSMNsList);
    for counter := 0 to length(MNsList)-1 do
      begin
      if MNsList[counter].Ip = LocalIP then
        begin
        result := true;
        break;
        end;
      end;
   LeaveCriticalSection(CSMNsList);
   end;
End;

Function IsLegitNewNode(ThisNode:TMNode;block:integer):Boolean;
var
  counter : integer;
Begin
  result := true;
  if GetMNsListLength>0 then
    begin
    EnterCriticalSection(CSMNsList);
    For counter := 0 to length(MNsList)-1 do
      begin
      if ( (ThisNode.Ip = MNsList[counter].Ip) or
           (ThisNode.Sign = MNsList[counter].Sign) or
           (ThisNode.Fund = MNsList[counter].Fund) or
           //(ThisNode.First>MyLastBlock) or
           //(ThisNode.Last>MyLastBlock) or
           //(ThisNode.Total<>0) or
           (GetAddressBalanceIndexed(ThisNode.Fund) < GetStackRequired(block+1)) or
           (ThisNode.Validations<>0) ) then
      begin
        Result := false;
        break;
      end;
    end;
    LeaveCriticalSection(CSMNsList);
  end;
End;

Function CheckMNReport(LineText:String;block:integer):String;
var
  StartPos   : integer;
  ReportInfo : string = '';
  NewNode    : TMNode;
  counter    : integer;
  Added      : boolean = false;
Begin
  Result := '';
  StartPos := Pos('$',LineText);
  ReportInfo := copy (LineText,StartPos,length(LineText));
  if GetMNodeFromString(ReportInfo,NewNode) then
    begin
    if IsLegitNewNode(NewNode,block) then
      begin
      EnterCriticalSection(CSMNsList);
      if Length(MNsList) = 0 then
         Insert(NewNode,MNsList,0)
      else
         begin
         for counter := 0 to length(MNsList)-1 do
            begin
            if NewNode.Ip<MNsList[counter].ip then
               begin
               Insert(NewNode,MNsList,counter);
               Added := true;
               break;
               end;
            end;
         if not Added then Insert(NewNode,MNsList,Length(MNsList));
         end;
      LeaveCriticalSection(CSMNsList);
      Result := reportinfo;
      end
    else
      begin
      //No legit masternode
      end;
    end
  else
    begin
    //Invalid masternode
    end;
End;

// Converts a String into a MNNode data
Function GetMNodeFromString(const StringData:String; out ToMNode:TMNode):Boolean;
var
  ErrCode : integer = 0;
Begin
  Result := true;
  ToMNode := Default(TMNode);
  ToMNode.Ip          := Parameter(StringData,1);
  ToMNode.Port        := StrToIntDef(Parameter(StringData,2),-1);
  ToMNode.Sign        := Parameter(StringData,3);
  ToMNode.Fund        := Parameter(StringData,4);
  ToMNode.First       := StrToIntDef(Parameter(StringData,5),-1);
  ToMNode.Last        := StrToIntDef(Parameter(StringData,6),-1);
  ToMNode.Total       := StrToIntDef(Parameter(StringData,7),-1);
  ToMNode.Validations := StrToIntDef(Parameter(StringData,8),-1);
  ToMNode.hash        := Parameter(StringData,9);
  If Not IsValidIP(ToMNode.Ip) then result := false
  else if ( (ToMNode.Port<0) or (ToMNode.Port>65535) ) then ErrCode := 1
  else if not IsValidHashAddress(ToMNode.Sign) then ErrCode := 2
  else if not IsValidHashAddress(ToMNode.Fund) then ErrCode := 3
  else if ToMNode.first < 0 then ErrCode := 4
  else if ToMNode.last < 0 then ErrCode := 5
  else if ToMNode.total <0 then ErrCode := 6
  else if ToMNode.validations < 0 then ErrCode := 7
  else if ToMNode.hash <> HashMD5String(ToMNode.Ip+IntToStr(ToMNode.Port)+ToMNode.Sign+ToMNode.Fund) then ErrCode := 8;
  if ErrCode>0 then
    begin
    Result := false;
    //Invalid Masternode
    end;
End;

// Converst a MNNode data into a string
Function GetStringFromMN(Node:TMNode):String;
Begin
  result := Node.Ip+' '+Node.Port.ToString+' '+Node.Sign+' '+Node.Fund+' '+Node.First.ToString+' '+Node.Last.ToString+' '+
          Node.Total.ToString+' '+Node.Validations.ToString+' '+Node.Hash;
End;

// Fills the given array with the nodes reports to be sent to another peer
Function FillMnsListArray(out LDataArray:TStringArray) : Boolean;
var
  ThisLine  : string;
  counter   : integer;
Begin
  result := false;
  SetLength(LDataArray,0);
  if GetMNsListLength>0 then
    begin
    EnterCriticalSection(CSMNsList);
    for counter := 0 to length(MNsList)-1 do
      begin
      ThisLine := GetStringFromMN(MNsList[counter]);
      Insert(ThisLine,LDataArray,length(LDataArray));
      end;
    result := true;
    LeaveCriticalSection(CSMNsList);
    end;
End;

// Returns the string to be stored on the masternodes.txt file
Function GetMNsAddresses(Block:integer):String;
var
  MinValidations : integer;
  Counter        : integer;
  Resultado      : string = '';
  AddAge         : string = '';
Begin
  MinValidations := (GetMNsChecksCount div 2) - 1;
  Resultado := Block.ToString+' ';
  EnterCriticalSection(CSMNsList);
  For counter := 0 to length(MNsList)-1 do
    begin
    if MNsList[counter].Validations>= MinValidations then
      begin
      AddAge := GetMNAgeCount(MNsList[counter]);
      Resultado := Resultado + MNsList[counter].Ip+';'+MNsList[counter].Port.ToString+':'+MNsList[counter].Fund+AddAge+' ';
      end;
    end;
  LeaveCriticalSection(CSMNsList);
  SetLength(Resultado, Length(Resultado)-1);
  result := Resultado;
End;

Procedure CreditMNVerifications();
var
  counter     : integer;
  NodesString : string;
  ThisIP      : string;
  IPIndex     : integer = 0;
  CheckNodes  : integer;

  Procedure AddCheckToIP(IP:String);
  var
    counter2 : integer;
  Begin
  For counter2 := 0 to length(MNsList)-1 do
     begin
     if MNsList[Counter2].Ip = IP then
        begin
        MNsList[Counter2].Validations := MNsList[Counter2].Validations+1;
        Break;
        end;
     end;
  End;

Begin
  EnterCriticalSection(CSMNsList);
  EnterCriticalSection(CSMNsChecks);
  for counter := 0 to length(ArrMNChecks)-1 do
    begin
    NodesString := ArrMNChecks[counter].ValidNodes;
    NodesString := StringReplace(NodesString,':',' ',[rfReplaceAll]);
    CheckNodes  := 0;
    IPIndex     := 0;
    REPEAT
      begin
      ThisIP := Parameter(NodesString,IPIndex);
      ThisIP := StringReplace(ThisIP,';',' ',[rfReplaceAll]);
      ThisIP := Parameter(ThisIP,0);
      if ThisIP <> '' then
        begin
        AddCheckToIP(ThisIP);
        Inc(CheckNodes);
        end;
      Inc(IPIndex);
      end;
    UNTIL ThisIP = '';
    //ToLog('Console',ArrMNChecks[counter].ValidatorIP+': '+Checknodes.ToString);
    end;
  LeaveCriticalSection(CSMNsChecks);
  LeaveCriticalSection(CSMNsList);
End;

{$ENDREGION MNsList handling}

{$REGION MNs check handling}

// Returns the number of MNs checks
Function GetMNsChecksCount():integer;
Begin
  EnterCriticalSection(CSMNsChecks);
  result := Length(ArrMNChecks);
  LeaveCriticalSection(CSMNsChecks);
End;

Function GetValidNodesCountOnCheck(StringNodes:String):integer;
var
  ThisIP  : string;
  IPIndex : integer = 0;
Begin
  Result := 0;
  StringNodes := StringReplace(StringNodes,':',' ',[rfReplaceAll]);
  IPIndex     := 0;
  REPEAT
    begin
    ThisIP := Parameter(StringNodes,IPIndex);
    if ThisIP <> '' then Inc(Result);
    Inc(IPIndex);
    end;
  UNTIL ThisIP = '';
End;

// Converts a string into a TMNChekc data
Function GetMNCheckFromString(Linea:String):TMNCheck;
Begin
  Result := Default(TMNCheck);
  Result.ValidatorIP    :=Parameter(Linea,5);
  Result.Block          :=StrToIntDef(Parameter(Linea,6),0);
  Result.SignAddress    :=Parameter(Linea,7);
  Result.PubKey         :=Parameter(Linea,8);
  Result.ValidNodes     :=Parameter(Linea,9);
  Result.Signature      :=Parameter(Linea,10);
End;

// Clears all the MNS checks
Procedure ClearMNsChecks();
Begin
  EnterCriticalSection(CSMNsChecks);
  SetLength(ArrMNChecks,0);
  LeaveCriticalSection(CSMNsChecks);
End;

// Verify if an IP already sent a verification
Function MnsCheckExists(Ip:String):Boolean;
var
  Counter : integer;
Begin
  result := false;
  EnterCriticalSection(CSMNsChecks);
  For counter := 0 to length(ArrMNChecks)-1 do
    begin
    if ArrMNChecks[counter].ValidatorIP = IP then
      begin
      result := true;
      break;
      end;
    end;
  LeaveCriticalSection(CSMNsChecks);
End;

// Adds a new MNCheck
Procedure AddMNCheck(ThisData:TMNCheck);
Begin
  EnterCriticalSection(CSMNsChecks);
  Insert(ThisData,ArrMNChecks,Length(ArrMNChecks));
  LeaveCriticalSection(CSMNsChecks);
End;

Function GetStringFromMNCheck(Data:TMNCheck): String;
Begin
  result := Data.ValidatorIP+' '+IntToStr(Data.Block)+' '+Data.SignAddress+' '+Data.PubKey+' '+
         Data.ValidNodes+' '+Data.Signature;
End;

Function IsMyMNCheckDone():Boolean;
var
  counter : integer;
Begin
  result := false;
  EnterCriticalSection(CSMNsChecks);
  for counter := 0 to length(ArrMNChecks)-1 do
    begin
    if ArrMNChecks[counter].ValidatorIP = LocalMN_IP then
      begin
      result := true;
      break;
      end;
    end;
  LeaveCriticalSection(CSMNsChecks);
End;

{$ENDREGION MNs check handling}

{$REGION MNs FileData handling}

Function GetMNAgeCount(TNode:TMNode):string;
var
  TIpandPort : string;
  counter    : integer;
  Number     : integer=0;
Begin
  result := '';
  TIpandPort := TNode.Ip+';'+IntToStr(TNode.Port);
  for counter := 0 to length(ArrayMNsData)-1 do
    begin
    if ( (TIpandPort = ArrayMNsData[counter].ipandport) and (TNode.Fund=ArrayMNsData[counter].address) ) then
      begin
      Number := ArrayMNsData[counter].age;
      break;
      end;
    end;
  result := ':'+IntToStr(number+1);
End;

{$ENDREGION MNs FileData handling}

{$REGION MNs hash}

Procedure SetMNsHash();
Begin
  EnterCriticalSection(CS_MNsHash);
  MyMNsHash := HashMD5File(MasterNodesFilename);
  LeaveCriticalSection(CS_MNsHash);
End;

Function GetMNsHash():String;
Begin
  EnterCriticalSection(CS_MNsHash);
  Result := HashMD5File(MasterNodesFilename);
  LeaveCriticalSection(CS_MNsHash);
End;

{$ENDREGION MNs hash}

{$REGION Received Masternodes}

Function LengthReceivedMNs():Integer;
Begin
  EnterCriticalSection(CSReceivedMNs);
  result := Length(ArrReceivedMNs);
  LeaveCriticalSection(CSReceivedMNs);
End;

Procedure ClearReceivedMNs();
Begin
  EnterCriticalSection(CSReceivedMNs);
  setlength(ArrReceivedMNs,0);
  LeaveCriticalSection(CSReceivedMNs);
End;

Function IsMNIPReceived(DataSource:String):boolean;
var
  counter : integer;
Begin
  Result := false;
  DataSource := Parameter(DataSource,5);
  EnterCriticalSection(CSReceivedMNs);
  for counter := 0 to length(ArrReceivedMNs)-1 do
    begin
    if ArrReceivedMNs[counter] = DataSource then
      begin
      Result := true;
      Break
      end;
    end;
  if not result then
    begin
    Insert(DataSource,ArrReceivedMNs,LEngth(ArrReceivedMNs))
    end;
  LeaveCriticalSection(CSReceivedMNs);
End;

{$ENDREGION Received Masternodes}

{$REGION Waiting Masternodes}

Function LengthWaitingMNs():Integer;
Begin
  EnterCriticalSection(CSWaitingMNs);
  result := Length(ArrWaitMNs);
  LeaveCriticalSection(CSWaitingMNs);
End;

Procedure AddWaitingMNs(Linea:String);
Begin
  if IsMNIPReceived(linea) then exit;;
  EnterCriticalSection(CSWaitingMNs);
  Insert(Linea,ArrWaitMNs,Length(ArrWaitMNs));
  LeaveCriticalSection(CSWaitingMNs);
End;

Function GetWaitingMNs():String;
Begin
  result := '';
  if LengthWaitingMNs>0 then
    begin
    EnterCriticalSection(CSWaitingMNs);
    Result := ArrWaitMNs[0];
    Delete(ArrWaitMNs,0,1);
    end;
  LeaveCriticalSection(CSWaitingMNs);
End;

{$ENDREGION Waiting Masternodes}

Function LoadMNsFile():String;
var
  lText   : string = '';
Begin
  Result := '';
  EnterCriticalSection(CSMNsFile);
  TRY
    reset(MNFileHandler);
    Readln(MNFileHandler,Result);
    Closefile(MNFileHandler);
  EXCEPT on E:Exception do
    begin
    ToDeepDeb('Nosomasternodes,LoadMNsFile,'+E.Message);
    end;
  END {TRY};
  LeaveCriticalSection(CSMNsFile);
  SetMN_FileText(result);
  //SetMNsHash;
End;

Procedure SaveMNsFile(GotText:string);
Begin
  EnterCriticalSection(CSMNsFile);
  TRY
    rewrite(MNFileHandler);
    write(MNFileHandler,GotText,#13#10);
    Closefile(MNFileHandler);
    SetMN_FileText(GotText);
  EXCEPT on E:Exception do
    begin
    ToDeepDeb('Nosomasternodes,SaveMNsFile,'+E.Message);
    SetMN_FileText('');
    end;
  END {TRY};
  LeaveCriticalSection(CSMNsFile);
  SetMNsHash;
End;

Procedure SetMN_FileText(lvalue:String);
Begin
  EnterCriticalSection(CSMN_FileText);
  MN_FileText := lvalue;
  FillMNsArray(lValue);
  //FillNodeList; <- Critical: needs to be redone
  LeaveCriticalSection(CSMN_FileText);
  SetMNsHash;
End;

Function GetMN_FileText():String;
Begin
  EnterCriticalSection(CSMN_FileText);
  Result := MN_FileText;
  LeaveCriticalSection(CSMN_FileText);
  FillMNsArray(result);
End;

Procedure FillMNsArray(TValue:String);
var
  counter   : integer = 1;
  count2    : integer = 0;
  ThisData  : string  = '';
  ThisMN    : TMNsData;
  TempArray : array of TMNsData;
  Added     : boolean = false;
  VerificatorsCount : integer;
Begin
  BeginPerformance('FillMNsArray');
  TRY
  SetLength(ArrayMNsData,0);
  SetLength(TempArray,0);
  Repeat
    ThisData := Parameter(Tvalue,counter);
    if ThisData <> '' then
      begin
      ThisData := StringReplace(ThisData,':',' ',[rfReplaceAll]);
      ThisMN.ipandport:=Parameter(ThisData,0);
      ThisMN.address  :=Parameter(ThisData,1);
      ThisMN.age      :=StrToIntDef(Parameter(ThisData,2),1);
      Insert(ThisMN,TempArray,length(TempArray));
      end;
    inc(counter);
  until thisData = '';
  for counter := 0 to length(TempArray)-1 do
    begin
    ThisMN := TempArray[counter];
    Added := false;
    if length(ArrayMNsData) = 0 then
      Insert(ThisMN,ArrayMNsData,0)
    else
      begin
      for count2 := 0 to length(ArrayMNsData)-1 do
        begin
        if ThisMN.age > ArrayMNsData[count2].age then
          begin
          Insert(ThisMN,ArrayMNsData,count2);
          added := true;
          break;
          end;
        end;
      if not added then Insert(ThisMN,ArrayMNsData,length(ArrayMNsData));
      end;
    end;
  EXCEPT on E:Exception do
    ToDeepDeb('Nosomasternodes,FillMNsArray,'+E.Message);
  END;
  EndPerformance('FillMNsArray');
End;

Function GetVerificatorsText():string;
var
  counter  : integer;
  VerCount : integer;
Begin
  Result := '';
  if length(ArrayMNsData)<3 then exit;
  VerCount :=  (length(ArrayMNsData) div 10)+3;
  for counter := 0 to VerCount-1 do
    begin
    Result:= Result+ArrayMNsData[counter].ipandport+':';
    end;
End;



INITIALIZATION
SetLength(MNsListCopy,0);
SetLength(MNsList,0);
SetLength(ArrayIPsProcessed,0);
SetLength(ArrMNChecks,0);
SetLength(ArrayMNsData,0);
Setlength(ArrWaitMNs,0);
Setlength(ArrReceivedMNs,0);
InitCriticalSection(CSMNsIPProc);
InitCriticalSection(CSMNsList);
InitCriticalSection(CSVerNodes);
InitCriticalSection(CSVerifyThread);
InitCriticalSection(CSMNsChecks);
InitCriticalSection(CSMNsFile);
InitCriticalSection(CS_MNsHash);
InitCriticalSection(CSWaitingMNs);
InitCriticalSection(CSMN_FileText);
InitCriticalSection(CSMNsChecks);
InitCriticalSection(CSReceivedMNs);


FINALIZATION
DoneCriticalSection(CSMNsIPProc);
DoneCriticalSection(CSMNsList);
DoneCriticalSection(CSVerNodes);
DoneCriticalSection(CSVerifyThread);
DoneCriticalSection(CSMNsChecks);
DoneCriticalSection(CSMNsFile);
DoneCriticalSection(CS_MNsHash);
DoneCriticalSection(CSWaitingMNs);
DoneCriticalSection(CSMN_FileText);
DoneCriticalSection(CSMNsChecks);
DoneCriticalSection(CSReceivedMNs);


END. // End unit


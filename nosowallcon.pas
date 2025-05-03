unit NosoWallCon;

{
  nosowallcon 1.1
  January 26th, 2024
  Stand-alone unit to control wallet addresses file and array.


# Documentation

## Types
### WalletData
A packed record representing wallet information:
- `Hash`: `String[40]` - The public hash or wallet address.
- `Custom`: `String[40]` - Custom name for the wallet address, if personalized.
- `PublicKey`: `String[255]` - The public key associated with the wallet.
- `PrivateKey`: `String[255]` - The private key associated with the wallet.
- `Balance`: `int64` - The last known balance of the wallet.
- `Pending`: `int64` - The last known pending balance of the wallet.
- `Score`: `int64` - The state or score of the wallet record.
- `LastOP`: `int64` - The Unix timestamp of the last operation.

## Functions and Procedures

### Wallet Management
- **`SetWalletFileName(Fname: String): Boolean`**
  Sets the wallet filename. If the file does not exist, it creates a new wallet file. Returns `false` if the file does not exist.

- **`ClearWalletArray()`**
  Clears the in-memory wallet array.

- **`InsertToWallArr(LData: WalletData): Boolean`**
  Inserts a wallet record into the wallet array if it does not already exist. Returns `true` if successful.

- **`GetWallArrIndex(Index: Integer): WalletData`**
  Retrieves a wallet record from the wallet array by index. Returns a default `WalletData` if the index is out of bounds.

- **`WallAddIndex(Address: String): Integer`**
  Finds the index of a wallet in the array by its hash or custom name. Returns `-1` if not found.

- **`LenWallArr(): Integer`**
  Returns the length of the wallet array.

- **`ChangeWallArrPos(PosA, PosB: Integer): Boolean`**
  Swaps the positions of two wallet records in the array. Returns `true` if successful.

- **`ClearWallPendings()`**
  Resets the pending balance of all wallets in the array to `0`.

- **`SetPendingForAddress(Index: Integer; Value: int64)`**
  Sets the pending balance for a specific wallet by index.

### File Operations
- **`GetAddressFromFile(FileLocation: String; out WalletInfo: WalletData): Boolean`**
  Reads a wallet record from a file. Returns `true` if successful.

- **`ImportAddressesFromBackup(BakFolder: String): Integer`**
  Imports wallet records from backup files in a specified folder. Returns the number of successfully imported records.

- **`SaveAddresstoFile(FileName: String; LData: WalletData): Boolean`**
  Saves a wallet record to a specified file. Returns `true` if successful.

- **`CreateNewWallet(): Boolean`**
  Creates a new wallet file with a newly generated address. Clears the wallet array before creation.

- **`GetWalletAsStream(out LStream: TMemoryStream): int64`**
  Loads the wallet file into a memory stream. Returns the size of the stream.

- **`SaveWalletToFile(): Boolean`**
  Saves the wallet array to the wallet file. Creates a backup of the file before saving. Returns `true` if successful.

- **`LoadWallet(wallet: String): Boolean`**
  Loads wallet records from a file into the wallet array. Returns `true` if successful.

- **`VerifyAddressOnDisk(HashAddress: String): Boolean`**
  Verifies if a specific wallet address exists in the wallet file. Returns `true` if found.

## Variables
- **`WalletArray: array of WalletData`**
  The in-memory array of wallet records.

- **`FileWallet: file of WalletData`**
  The file used to store wallet records.

- **`WalletFilename: string`**
  The default filename for the wallet file (`NOSODATA/wallet.pkw`).

- **`CS_WalletFile: TRTLCriticalSection`**
  Critical section for synchronizing access to the wallet file.

- **`CS_WalletArray: TRTLCriticalSection`**
  Critical section for synchronizing access to the wallet array.

## Initialization and Finalization
- **Initialization**
  - Initializes critical sections for `CS_WalletArray` and `CS_WalletFile`.
  - Sets the initial length of `WalletArray` to `0`.

- **Finalization**
  - Frees the critical sections for `CS_WalletArray` and `CS_WalletFile`.
nosowallcon 1.1
January 26th, 2024
Stand alone unit to control wallet addresses file and array
}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fileutil, nosodebug,nosocrypto,nosogeneral,nosoheaders,nosonetwork;

TYPE

  WalletData = Packed Record
    Hash : String[40];        // El hash publico o direccion
    Custom : String[40];      // En caso de que la direccion este personalizada
    PublicKey : String[255];  // clave publica
    PrivateKey : String[255]; // clave privada
    Balance : int64;          // el ultimo saldo conocido de la direccion
    Pending : int64;          // el ultimo saldo de pagos pendientes
    Score : int64;            // estado del registro de la direccion.
    LastOP : int64;           // tiempo de la ultima operacion en UnixTime.
    end;

Function SetWalletFileName(Fname:String):Boolean;
Procedure ClearWalletArray();
function InsertToWallArr(LData:WalletData):boolean;
Function GetWallArrIndex(Index:integer):WalletData;
Function WallAddIndex(Address:String):integer;
Function LenWallArr():Integer;
Function ChangeWallArrPos(PosA,PosB:integer):boolean;
Procedure ClearWallPendings();
Procedure SetPendingForAddress(Index:integer;value:int64);
Function GetAddressFromFile(FileLocation:String;out WalletInfo:WalletData):Boolean;
Function ImportAddressesFromBackup(BakFolder:String):integer;
Function SaveAddresstoFile(FileName:string;LData:WalletData):boolean;

function CreateNewWallet():Boolean;
Function GetWalletAsStream(out LStream:TMemoryStream):int64;
Function SaveWalletToFile():boolean;
Function LoadWallet(wallet:String):Boolean;
Function VerifyAddressOnDisk(HashAddress:String):boolean;



var
  WalletArray     : array of walletData; // Wallet addresses
  FileWallet      : file of WalletData;
  WalletFilename  : string= 'NOSODATA'+DirectorySeparator+'wallet.pkw';
  CS_WalletFile   : TRTLCriticalSection;
  CS_WalletArray  : TRTLCriticalSection;

IMPLEMENTATION

// Set the wallet filename; if not exists, returns false
Function SetWalletFileName(Fname:String):Boolean;
Begin
  Result := true;
  WalletFilename := Fname;//'NOSODATA'+DirectorySeparator+'wallet.pkw';
  if not FileExists(WalletFilename) then
    begin
    CreateNewWallet;
    result := false;
    end
  else LoadWallet(WalletFilename);
End;

Procedure ClearWalletArray();
Begin
  EnterCriticalSection(CS_WalletArray);
  setlength(WalletArray,0);
  LeaveCriticalSection(CS_WalletArray);
End;

function InsertToWallArr(LData:WalletData):boolean;
Begin
  result := false;
  if WallAddIndex(LData.Hash)<0 then
    begin
    EnterCriticalSection(CS_WalletArray);
    Insert(LData,WalletArray,length(WalletArray));
    LeaveCriticalSection(CS_WalletArray);
    Result := true;
    end;
End;

Function GetWallArrIndex(Index:integer):WalletData;
Begin
  EnterCriticalSection(CS_WalletArray);
  if Index <= Length(WalletArray)-1 then
    Result := WalletArray[Index]
  else result := Default(WalletData);
  LeaveCriticalSection(CS_WalletArray);
End;

Function WallAddIndex(Address:String):integer;
var
  counter : integer;
Begin
  Result := -1;
  if ((Address ='') or (length(Address)<5)) then exit;
  EnterCriticalSection(CS_WalletArray);
  for counter := 0 to high(WalletArray) do
    if ((WalletArray[counter].Hash = Address) or (WalletArray[counter].Custom = Address )) then
      Begin
      Result := counter;
      break;
      end;
  LeaveCriticalSection(CS_WalletArray);
End;

Function LenWallArr():Integer;
Begin
  EnterCriticalSection(CS_WalletArray);
  Result := Length(WalletArray);
  LeaveCriticalSection(CS_WalletArray);
End;

Function ChangeWallArrPos(PosA,PosB:integer):boolean;
var
  oldData,NewData : WalletData;
Begin
  Result := false;
  if posA>LenWallArr-1 then exit;
  if posB>LenWallArr-1 then exit;
  if posA=posB then Exit;
  OldData := GetWallArrIndex(posA);
  NewData := GetWallArrIndex(posB);
  EnterCriticalSection(CS_WalletArray);
  WalletArray[posA] := NewData;
  WalletArray[posB] := OldData;
  LeaveCriticalSection(CS_WalletArray);
  Result := true;
End;

Procedure ClearWallPendings();
var
  counter : integer;
Begin
  EnterCriticalSection(CS_WalletArray);
  for counter := 0 to length(WalletArray)-1 do
    WalletArray[counter].pending := 0;
  LeaveCriticalSection(CS_WalletArray);
End;

Procedure SetPendingForAddress(Index:integer;value:int64);
Begin
  if Index > LenWallArr-1 then exit;
  EnterCriticalSection(CS_WalletArray);
  WalletArray[Index].pending := value;
  LeaveCriticalSection(CS_WalletArray);
End;

// Import an address data from a file
Function GetAddressFromFile(FileLocation:String;out WalletInfo:WalletData):Boolean;
var
  TempFile : File of WalletData;
  Opened   : boolean = false;
  Closed   : boolean = false;
Begin
  result := true;
  AssignFile(TempFile,FileLocation);
  TRY
    Reset(TempFile);
    Opened := true;
    Read(TempFile,WalletInfo);
    CloseFile(TempFile);
    Closed := true;
  EXCEPT on E:Exception do
    begin
    Result := false;
    ToDeepDeb('NosoWallcon,GetAddressFromFile,'+E.Message);
    end;
  END;
  If ( (opened) and (not Closed) ) then CloseFile(TempFile);
End;

// Verify if all baked up keys are present on active wallet
Function ImportAddressesFromBackup(BakFolder:String):integer;
Var
  BakFiles    : TStringList;
  Counter     : integer = 0;
  ThisData    : WalletData;
Begin
  Result := 0;
  BeginPerformance('ImportAddressesFromBackup');
  BakFiles := TStringList.Create;
  TRY
    FindAllFiles(BakFiles, BakFolder, '*.pkw', true);
    while Counter < BakFiles.Count do
        begin
        if GetAddressFromFile(BakFiles[Counter],ThisData) then
          begin
          if InsertToWallArr(ThisData) then inc(result);
          end;
        Inc(Counter);
        end;
    if result > 0 then ToDeepDeb(format('Imported %d addresses from backup files',[result]));
  EXCEPT on E:Exception do
    begin
    ToDeepDeb('NosoWallcon,ImportAddressesFromBackup,'+E.Message);
    end;
  END;
  BakFiles.free;
  EndPerformance('ImportAddressesFromBackup');
End;

// Saves an address info to a specific file
Function SaveAddresstoFile(FileName:string;LData:WalletData):boolean;
var
  TempFile : File of WalletData;
  opened   : boolean = false;
  Closed   : boolean = false;
Begin
  Result := true;
  AssignFile(TempFile,FileName);
  TRY
    rewrite(TempFile);
    opened := true;
    write(TempFile,Ldata);
    CloseFile(TempFile);
    Closed := true;
  EXCEPT on E:Exception do
    begin
    Result := false;
    ToDeepDeb('NosoWallcon,SaveAddresstoFile,'+E.Message);
    end;
  END;
  If ( (opened) and (not Closed) ) then CloseFile(TempFile);
End;

// Creates a new wallet file with a new generated address
function CreateNewWallet():Boolean;
var
  NewAddress : WalletData;
  PubKey,PriKey : string;
Begin
  TRY
  if not fileexists (WalletFilename) then // Check to avoid delete an existing file
    begin
    ClearWalletArray;
    NewAddress := Default(WalletData);
    NewAddress.Hash:=GenerateNewAddress(PubKey,PriKey);
    NewAddress.PublicKey:=pubkey;
    NewAddress.PrivateKey:=PriKey;
    InsertToWallArr(NewAddress);
    SaveWalletToFile;
    end;
   EXCEPT on E:Exception do
     begin
     ToDeepDeb('NosoWallcon,CreateNewWallet,'+E.Message);
     end;
   END; {TRY}
End;

// Load the wallet file into a memory stream
Function GetWalletAsStream(out LStream:TMemoryStream):int64;
Begin
  Result := 0;
  EnterCriticalSection(CS_WalletFile);
    TRY
    LStream.LoadFromFile(WalletFilename);
    result:= LStream.Size;
    LStream.Position:=0;
    EXCEPT ON E:Exception do
      begin
      ToDeepDeb('NosoWallcon,GetWalletAsStream,'+E.Message);
      end;
    END{Try};
  LeaveCriticalSection(CS_WalletFile);
End;

// Save the wallet array to the file
Function SaveWalletToFile():boolean;
var
  MyStream : TMemoryStream;
  Counter  : integer;
Begin
  Result := true;
  TryCopyFile(WalletFilename,WalletFilename+'.bak');
  MyStream:= TMemoryStream.Create;
  MyStream.Position:=0;
  EnterCriticalSection(CS_WalletFile);
  EnterCriticalSection(CS_WalletArray);
  for Counter := 0 to length(WalletArray)-1 do
    begin
    MyStream.Write(WalletArray[counter],SizeOf(WalletData));
    end;
    TRY
    MyStream.SaveToFile(WalletFilename);
    EXCEPT ON E:EXCEPTION DO
      begin
      ToDeepDeb('NosoWallcon,SaveWalletToFile,'+E.Message);
      Result := false;
      end;
    END;
  LeaveCriticalSection(CS_WalletArray);
  LeaveCriticalSection(CS_WalletFile);
  MyStream.Free;
  If result = true then TryCopyFile(WalletFilename,WalletFilename+'.bak')
  else TryCopyFile(WalletFilename+'.bak',WalletFilename);
End;

Function LoadWallet(wallet:String):Boolean;
var
  MyStream    : TMemoryStream;
  ThisAddress : WalletData;
  Counter     : integer;
  Records     : integer;
Begin
  Result := true;
  MyStream := TMemoryStream.Create;
  if fileExists(wallet) then
    begin
    Records := GetWalletAsStream(MyStream) div sizeof(WalletData);
    if Records > 0 then
      begin
      ClearWalletArray;
      For counter := 0 to records-1 do
        begin
        MyStream.Read(ThisAddress,Sizeof(WalletData));
        InsertToWallArr(ThisAddress);
        end;
      end
    else result := false;
    end
  else result := false;
  MyStream.Free;
End;

Function VerifyAddressOnDisk(HashAddress:String):boolean;
var
  MyStream    : TMemoryStream;
  ThisAddress : WalletData;
  Counter     : integer;
  Records     : integer;
Begin
  Result := false;
  MyStream := TMemoryStream.Create;
  if fileExists(WalletFilename) then
    begin
    Records := GetWalletAsStream(MyStream) div sizeof(WalletData);
    if Records > 0 then
      begin
      For counter := 0 to records-1 do
        begin
        MyStream.Read(ThisAddress,Sizeof(WalletData));
        if ThisAddress.Hash=HashAddress then
          begin
          result := true;
          break;
          end;
        end;
      end
    else result := false;
    end
  else result := false;
  MyStream.Free;
End;

{$REGION Summary related}



{$ENDREGION Summary related}

INITIALIZATION
InitCriticalSection(CS_WalletArray);
InitCriticalSection(CS_WalletFile);
SetLength(WalletArray,0);

FINALIZATION
DoneCriticalSection(CS_WalletArray);
DoneCriticalSection(CS_WalletFile);
END.





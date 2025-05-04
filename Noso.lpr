{// ============================================================================
// Назва файлу: Noso.lpr
// Опис: Головний файл програми Noso, яка є частиною проєкту NosoNode.
//        Відповідає за ініціалізацію та запуск графічного інтерфейсу користувача (GUI)
//        з використанням бібліотеки LCL (Lazarus Component Library).
// Автор: [Вкажіть автора]
// Дата створення: [Вкажіть дату]
// Ліцензія: [Вкажіть ліцензію, якщо потрібно]
// 
// Основні компоненти:
//   - Імпортує необхідні модулі для роботи з GUI, мережевими протоколами, блокчейном,
//     криптографією, перекладами, системними перевірками та іншими функціями.
//   - Використовує директиви компілятора для підтримки різних ОС (наприклад, UNIX).
//   - Створює головну форму додатку (TForm1) та запускає цикл обробки подій.
// 
// Призначення:
//   - Запуск та ініціалізація основного GUI-додатку NosoNode.
// ============================================================================}
program Noso;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, MasterPaskalForm, mpGUI, mpdisk, mpParser, mpRed, mpProtocol, mpBlock,
  mpCoin, mpsignerutils, mpRPC, translation, indylaz, sysutils, LCLTranslator,
  mpsyscheck, NosoTime, nosodebug, nosogeneral, nosocrypto, nosounit,
  nosoconsensus, nosopsos, nosowallcon, NosoHeaders, NosoNosoCFG, NosoBlock,
  NosoNetwork, NosoClient, nosogvts, nosomasternodes, nosoIPControl;

{$R *.res}

begin
  Application.Scaled:=True;
  Application.Initialize;

  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.


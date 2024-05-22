program VStarCamDownloaderLinux;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  uSettings in 'uSettings.pas',
  uVStarCamDownloader in 'uVStarCamDownloader.pas',
  uDownloaderEngine in 'uDownloaderEngine.pas';

Type
  TDummy = Class
    Class Procedure ConsoleWrite(inText: String);
  End;
Var
  vsdl: TVStarCamDownloader;

Class Procedure TDummy.ConsoleWrite(inText: String);
Begin
  WriteLn(inText);
End;

Begin
  vsdl := TVStarCamDownloader.Create(TDummy.ConsoleWrite);
  Try
    ReadLn;
  Finally
    FreeAndNil(vsdl);
  End;
End.

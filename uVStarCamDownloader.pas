Unit uVStarCamDownloader;

Interface

Uses AE.Application.Application, uDownloaderEngine, System.Generics.Collections;

Type
 TVStarCamDownloader = Class(TAEApplication)
 strict private
  _engines: TObjectList<TDownloaderEngine>;
 strict protected
  Procedure Creating; Override;
  Procedure Destroying; Override;
 End;

Implementation

Uses uSettings, System.SysUtils, System.IOUtils;

Procedure TVStarCamDownloader.Creating;
Var
 camera: String;
Begin
 inherited;

 If Not Settings.IsLoaded Then Begin
                               Log('Settings file could not be loaded! Exiting...');
                               Halt(1);
                               End;
 Log('Download location: ' + Settings.DownloadLocation);
 If Not TDirectory.Exists(Settings.DownloadLocation) Then Begin
                                                          Log('Attempting to create directory...');
                                                          TDirectory.CreateDirectory(Settings.DownloadLocation);
                                                          End;

 _engines := TObjectList<TDownloaderEngine>.Create(True);
 Self.Log('Starting engines...');
 For camera In Settings.Cameras Do
  Begin
   _engines.Add(TDownloaderEngine.Create(Log));
   _engines[_engines.Count - 1].SetCameraName(camera);
   _engines[_engines.Count - 1].Start;
  End;
End;

Procedure TVStarCamDownloader.Destroying;
Begin
 inherited;

 _engines.Free;
End;

End.

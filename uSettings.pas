{
  VStarcamDownloader © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit uSettings;

Interface

Uses AE.Application.Setting, AE.Application.Settings, System.JSON, System.Generics.Collections;

Type
  TCamera = Class(TAEApplicationSetting)
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    DownloadAll: Boolean;
    Hostname: String;
    Password: String;
    UserName: String;
  End;

  TSettings = Class(TAEApplicationSettings)
  strict private
    _cameras: TObjectDictionary<String, TCamera>;
    Procedure SetCamera(inCameraName: String; inCamera: TCamera);
    Function GetCamera(inCameraName: String): TCamera;
    Function GetCameras: TArray<String>;
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    DownloadLocation: String;
    Constructor Create(Const inSettingsFileName: String); Override;
    Destructor Destroy; Override;
    Property Cameras: TArray<String> Read GetCameras;
    Property Camera[inCameraName: String]: TCamera Read GetCamera Write SetCamera;
  End;

Var
  Settings: TSettings;

Implementation

Uses System.SysUtils;

Const
  TXT_DOWNLOADALL = 'downloadall';
  TXT_HOSTNAME = 'hostname';
  TXT_LASTDOWNLOAD = 'lastdownload';
  TXT_PASSWORD = 'password';
  TXT_USERNAME = 'username';
  TXT_CAMERAS = 'cameras';
  TXT_DOWNLOADLOCATION = 'downloadlocation';

//
// TCameraInfo
//

Function TCamera.GetAsJSON: TJSONObject;
Begin
 Result := inherited;

 If Not Self.Hostname.IsEmpty Then
   Result.AddPair(TXT_HOSTNAME, TJSONString.Create(Self.Hostname));

 If Not Self.Password.IsEmpty Then
   Result.AddPair(TXT_PASSWORD, TJSONString.Create(Self.Password));

 If Self.UserName <> 'admin' Then
   Result.AddPair(TXT_USERNAME, TJSONString.Create(Self.UserName));
End;

Procedure TCamera.InternalClear;
Begin
  inherited;

  Self.DownloadAll := False;
  Self.Hostname := '';
  Self.Password := '';
  Self.UserName := 'admin';
End;

Procedure TCamera.SetAsJSON(Const inJSON: TJSONObject);
Begin
  inherited;

  If inJSON.GetValue(TXT_DOWNLOADALL) <> nil Then
    Self.DownloadAll := TJSONBool(inJSON.GetValue(TXT_DOWNLOADALL)).AsBoolean;

  If inJSON.GetValue(TXT_HOSTNAME) <> nil Then
    Self.Hostname := TJSONString(inJSON.GetValue(TXT_HOSTNAME)).Value;

  If inJSON.GetValue(TXT_PASSWORD) <> nil Then
    Self.Password := TJSONString(inJSON.GetValue(TXT_PASSWORD)).Value;

  if inJSON.GetValue(TXT_USERNAME) <> nil Then
    Self.UserName := TJSONString(inJSON.GetValue(TXT_USERNAME)).Value;
End;

//
// TSettings
//

Constructor TSettings.Create(Const inSettingsFileName: String);
Begin
  inherited;

  _cameras := TObjectDictionary<String, TCamera>.Create([doOwnsValues]);
End;

Destructor TSettings.Destroy;
Begin
  FreeAndNil(_cameras);

  inherited;
End;

Function TSettings.GetAsJSON: TJSONObject;
Var
  json: TJSONObject;
  camera: String;
Begin
  Result := inherited;

  If Not Self.DownloadLocation.IsEmpty Then
    Result.AddPair(TXT_DOWNLOADLOCATION, TJSONString.Create(Self.DownloadLocation));
  If _cameras.Count > 0 Then
  Begin
    json := TJSONObject.Create;
    Try
      For camera In _cameras.Keys Do
        json.AddPair(camera, _cameras[camera].AsJSON);
    Finally
      If json.Count = 0 Then
        FreeAndNil(json)
      Else
        Result.AddPair(TXT_CAMERAS, json);
    End;
  End;
End;

Function TSettings.GetCamera(inCameraName: String): TCamera;
Begin
  _cameras.TryGetValue(inCameraName, Result);
End;

Function TSettings.GetCameras: TArray<String>;
Begin
  Result := _cameras.Keys.ToArray;
End;

Procedure TSettings.InternalClear;
Begin
  inherited;

  _cameras.Clear;

  Self.DownloadLocation := '';
End;

Procedure TSettings.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
Begin
  inherited;

  If inJSON.GetValue(TXT_DOWNLOADLOCATION) <> nil Then
    Self.DownloadLocation := TJSONString(inJSON.GetValue(TXT_DOWNLOADLOCATION)).Value;

  If inJSON.GetValue(TXT_CAMERAS) <> nil Then
    For jp In TJSONObject(inJSON.GetValue(TXT_CAMERAS)) Do
      _cameras.Add(jp.JsonString.Value, TCamera(TCamera.NewFromJSON(jp.JsonValue)));
End;

Procedure TSettings.SetCamera(inCameraName: String; inCamera: TCamera);
Begin
  If Assigned(inCamera) Then
    _cameras.AddOrSetValue(inCameraName, inCamera)
  Else If _cameras.ContainsKey(inCameraName) Then
    _cameras.Remove(inCameraName);
End;

Initialization
  Settings := TSettings.New(slNextToExe, scUncompressed) As TSettings;
  Settings.Load;

Finalization
  Settings.Save;
  FreeAndNil(Settings);

End.

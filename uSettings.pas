Unit uSettings;

Interface

Uses AE.Application.Setting, AE.Application.Settings, System.JSON, System.Generics.Collections;

Type
 TCamera = Class(TAEApplicationSetting)
 strict protected
  Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
  Function GetAsJSON: TJSONObject; Override;
 public
  Hostname: String;
  Password: String;
  LastDownload: TDateTime;
  Constructor Create; Override;
 End;

 TSettings = Class(TAEApplicationSettings)
 strict private
  _cameras: TObjectDictionary<String, TCamera>;
  Procedure SetCamera(inCameraName: String; inCamera: TCamera);
  Function GetCamera(inCameraName: String): TCamera;
  Function GetCameras: TArray<String>;
 strict protected
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
 TXT_HOSTNAME = 'hostname';
 TXT_PASSWORD = 'password';
 TXT_LASTDOWNLOAD = 'lastdownload';
 TXT_CAMERAS = 'cameras';
 TXT_DOWNLOADLOCATION = 'downloadlocation';

//
// TCameraInfo
//

Constructor TCamera.Create;
Begin
 inherited;
 Self.Hostname := '';
 Self.Password := '';
 Self.LastDownload := 0;
End;

Function TCamera.GetAsJSON: TJSONObject;
Begin
 Result := inherited;
 If Not Self.Hostname.IsEmpty Then Result.AddPair(TXT_HOSTNAME, TJSONString.Create(Self.Hostname));
 If Not Self.Password.IsEmpty Then Result.AddPair(TXT_PASSWORD, TJSONString.Create(Self.Password));
 If Self.LastDownload > 0 Then Result.AddPair(TXT_LASTDOWNLOAD, TJSONNumber.Create(Self.LastDownload));
End;

Procedure TCamera.SetAsJSON(Const inJSON: TJSONObject);
Begin
 inherited;
 If inJSON.GetValue(TXT_HOSTNAME) <> nil Then Self.Hostname := TJSONString(inJSON.GetValue(TXT_HOSTNAME)).Value;
 If inJSON.GetValue(TXT_PASSWORD) <> nil Then Self.Password := TJSONString(inJSON.GetValue(TXT_PASSWORD)).Value;
 If inJSON.GetValue(TXT_LASTDOWNLOAD) <> nil Then Self.LastDownload := TJSONNumber(inJSON.GetValue(TXT_LASTDOWNLOAD)).AsDouble;
End;

//
// TSettings
//

Constructor TSettings.Create(Const inSettingsFileName: String);
Begin
 inherited;
 _cameras := TObjectDictionary<String, TCamera>.Create([doOwnsValues]);
 Self.DownloadLocation := '';
End;

Destructor TSettings.Destroy;
Begin
 If Assigned(_cameras) Then FreeAndNil(_cameras);
 inherited;
End;

Function TSettings.GetAsJSON: TJSONObject;
Var
 json: TJSONObject;
 camera: String;
Begin
 Result := inherited;
 If Not Self.DownloadLocation.IsEmpty Then Result.AddPair(TXT_DOWNLOADLOCATION, TJSONString.Create(Self.DownloadLocation));
 If _cameras.Count > 0 Then Begin
                            json := TJSONObject.Create;
                            Try
                             For camera In _cameras.Keys Do
                              json.AddPair(camera, _cameras[camera].AsJSON);
                            Finally
                             If json.Count = 0 Then FreeAndNil(json)
                               Else Result.AddPair(TXT_CAMERAS, json);
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

Procedure TSettings.SetAsJSON(Const inJSON: TJSONObject);
Var
 enum: TJSONObject.TEnumerator;
Begin
 inherited;
 If inJSON.GetValue(TXT_DOWNLOADLOCATION) <> nil Then Self.DownloadLocation := TJSONString(inJSON.GetValue(TXT_DOWNLOADLOCATION)).Value;
 If inJSON.GetValue(TXT_CAMERAS) <> nil Then Begin
                                             enum := TJSONObject(inJSON.GetValue(TXT_CAMERAS)).GetEnumerator;
                                             If Assigned(enum) Then Try
                                                                     While enum.MoveNext Do
                                                                      _cameras.Add(enum.Current.JsonString.Value, TCamera(TCamera.NewFromJSON(enum.Current.JsonValue)));
                                                                    Finally
                                                                     FreeAndNil(enum);
                                                                    End;
                                             End;
End;

Procedure TSettings.SetCamera(inCameraName: String; inCamera: TCamera);
Begin
 If Assigned(inCamera) Then _cameras.AddOrSetValue(inCameraName, inCamera)
   Else
 If _cameras.ContainsKey(inCameraName) Then _cameras.Remove(inCameraName);
End;

Initialization
 Settings := TSettings.New(slNextToExe, scUncompressed) As TSettings;
 Settings.Load;

Finalization
 Settings.Save;
 FreeAndNil(Settings);

End.

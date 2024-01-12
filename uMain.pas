unit uMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  REST.Types,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  System.Rtti,
  FMX.Grid.Style,
  FMX.ScrollBox,
  FMX.Grid,
  Data.DB,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  REST.Response.Adapter,
  REST.Client,
  Data.Bind.Components,
  Data.Bind.ObjectScope,
  Data.Bind.EngExt,
  FMX.Bind.DBEngExt,
  FMX.Bind.Grid,
  System.Bindings.Outputs,
  FMX.Bind.Editors,
  Data.Bind.Grid,
  Data.Bind.DBScope,
  FMX.Memo.Types,
  FMX.Memo,
  OJsonPTree,
  OXmlUtils,
  IdHTTPProgressU,
  IdHashMessageDigest,
  Winapi.ShellAPI,
  FMX.Platform.Win,
  Winapi.Windows;

type
  TForm1 = class(TForm)
    btnInstallMariaDB: TButton;
    RESTClient_MariaDB: TRESTClient;
    RESTRequest_MariaDB: TRESTRequest;
    RESTResponse_MariaDB: TRESTResponse;
    RESTResponseDataSetAdapter_MariaDB: TRESTResponseDataSetAdapter;
    FDMemTable_MariaDB: TFDMemTable;
    DataSource_MariaDB: TDataSource;
    BindSourceDB1: TBindSourceDB;
    BindingsList1: TBindingsList;
    lbl_MariaDBInfo: TLabel;
    ProgressBar1: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure btnInstallMariaDBClick(Sender: TObject);
  private  { Private declarations }

    procedure IdHTTPProgressOnChange(Sender: TObject);
  public    { Public declarations }

    IdHTTPProgress: TIdHTTPProgress;

  end;

function MD5File(const FileName: string): string;

function RunMSIExec(Params: string): DWORD;

var
  Form1: TForm1;
  FileURL: string;
  FileMD5: string;
  FileName: string;

implementation

{$R *.fmx}

procedure TForm1.IdHTTPProgressOnChange(Sender: TObject);
begin
  ProgressBar1.Value := TIdHTTPProgress(Sender).Progress;
  Application.ProcessMessages;
end;

procedure TForm1.btnInstallMariaDBClick(Sender: TObject);
var
  MariaProps: string;
  ExitCode: DWORD;
begin
  if FileURL <> 'missing' then
  begin
    btnInstallMariaDB.Text := 'Downloading...';
    btnInstallMariaDB.Enabled := False;
    Application.ProcessMessages;

    IdHTTPProgress := TIdHTTPProgress.Create(Self);
    IdHTTPProgress.OnChange := IdHTTPProgressOnChange;

    IdHTTPProgress.Free;

    btnInstallMariaDB.Text := 'Validating MD5...';
    Application.ProcessMessages;

    if MD5File(FileName).ToUpper = FileMD5.ToUpper then
    begin
      btnInstallMariaDB.Text := 'MD5 Validated';

      MariaProps := '/i ' + FileName + ' PORT=3311 SERVICENAME=MariaDB UTF8=True PASSWORD=CMCMPass /qn /l*v MariaDBInstallLog.txt';
      ExitCode := RunMSIExec(MariaProps);
      If ExitCode = 0 then
        btnInstallMariaDB.Text := 'MariaDB Installed'
      else
        btnInstallMariaDB.Text := '[ERROR] ' + ExitCode.ToString;     //1602 - aborted
    end
    else
    begin
      btnInstallMariaDB.Text := 'Download Failed!';
      ShowMessage('ERROR - MD5 Mismatch: ' + #13#10 + FileMD5.ToUpper + ' (Reference)' + #13#10 + MD5File(FileName).ToUpper + ' (Calculated)');
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  JSONDoc: TJSONDocument;
  NodeList: IJSONNodeList;
  ANode: PJSONNode;
  FilterArray: TJSONNodeFilterFunction;
  Release_ID: string;
  Release_Name: string;
begin
  Release_ID := 'missing';
  FileURL := 'missing';
  RESTRequest_MariaDB.Client.BaseURL := 'https://downloads.mariadb.org/rest-api/mariadb/';
  RESTRequest_MariaDB.Execute;
  JSONDoc := TJSONDocument.Create;
  JSONDoc.LoadFromJSON(RESTRequest_MariaDB.Response.Content);
  JSONDoc.Node.SelectNodes('$[''major_releases''][*]', NodeList);
  ANode := NodeList.GetFirst;
  while ANode <> nil do
  begin
    if ANode.FindPairValueDef('release_status', 'X') = 'Stable' then
    begin
      Release_ID := ANode.FindPairValueDef('release_id', 'X');
      Break;
    end;
    NodeList.GetNext(ANode);
  end;

  NodeList.Clear;
  JSONDoc.Free;

  if Release_ID <> 'missing' then
  begin
    RESTRequest_MariaDB.ClearBody;
    RESTRequest_MariaDB.Client.BaseURL := 'https://downloads.mariadb.org/rest-api/mariadb/' + Release_ID + '/';
    RESTRequest_MariaDB.Execute;
    JSONDoc := TJSONDocument.Create;
    JSONDoc.LoadFromJSON(RESTRequest_MariaDB.Response.Content);
    JSONDoc.Node.SelectNodes('$[''releases''].[''*'']', NodeList);
    ANode := NodeList.GetFirst;
    Release_Name := ANode.FindPairValueDef('release_name', 'X');
    lbl_MariaDBInfo.Text := 'Release Name:  ' + Release_Name + #13#10;
    lbl_MariaDBInfo.Text := lbl_MariaDBInfo.Text + 'Release Date:  ' + ANode.FindPairValueDef('date_of_release', 'X') + #13#10;
    NodeList := ANode.SelectNodes('[''files''].[''*'']');
    ANode := NodeList.GetFirst;
    while ANode <> nil do
    begin
      if ANode.FindPairValueDef('package_type', 'X') = 'MSI Package' then
      begin
        FileURL := ANode.FindPairValueDef('file_download_url', 'X');
        FileName := ANode.FindPairValueDef('file_name', 'X');
        lbl_MariaDBInfo.Text := lbl_MariaDBInfo.Text + 'File Name:  ' + FileName + #13#10 + 'File URL:  ' + FileURL + #13#10;
        ANode := ANode.SelectNode('[''checksum'']');
        FileMD5 := ANode.FindPairValueDef('md5sum', 'X');
        lbl_MariaDBInfo.Text := lbl_MariaDBInfo.Text + 'MD5 Checksum:  ' + FileMD5;
        btnInstallMariaDB.Enabled := True;
        Break;
      end;
      NodeList.GetNext(ANode);
    end;

  end;

end;

function MD5File(const FileName: string): string;
var
  IdMD5: TIdHashMessageDigest5;
  FS: TFileStream;
begin
  IdMD5 := TIdHashMessageDigest5.Create;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := IdMD5.HashStreamAsHex(FS)
  finally
    FS.Free;
    IdMD5.Free;
  end;
end;

function RunMSIExec(Params: string): DWORD;
var
  SEInfo: TShellExecuteInfo;
  ExitCode: DWORD;
  ExecuteFile, StartInString: string;
begin
  ExecuteFile := 'MSIExec.exe';

  FillChar(SEInfo, SizeOf(SEInfo), 0);
  SEInfo.cbSize := SizeOf(TShellExecuteInfo);
  with SEInfo do begin
    fMask := SEE_MASK_NOCLOSEPROCESS;
    Wnd := FmxHandleToHWND(Form1.Handle);
    lpFile := PChar(ExecuteFile);
    lpParameters := PChar(Params);
                {
                  StartInString specifies the
                  name of the working directory.
                  If ommited, the current directory is used.
                }
                // lpDirectory := PChar(StartInString) ;
    nShow := SW_SHOWNORMAL;
  end;
  if ShellExecuteEx(@SEInfo) then
  begin
    repeat
      Application.ProcessMessages;
      GetExitCodeProcess(SEInfo.hProcess, ExitCode);
    until (ExitCode <> STILL_ACTIVE) or Application.Terminated;
    Result := ExitCode;
  end
  else
    Result := 187;
end;

end.


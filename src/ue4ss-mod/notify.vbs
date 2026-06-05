Dim fso, shell, scriptDir, ps1, msgFile, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = scriptDir & "\notify.ps1"

If WScript.Arguments.Count < 1 Then
    WScript.Quit 1
End If

msgFile = WScript.Arguments(0)
cmd = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """ -MessageFile """ & msgFile & """"
shell.Run cmd, 0, False

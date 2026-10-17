#Requires AutoHotkey v2.0
#SingleInstance Force

; Claude デスクトップアプリの窓の中だけ: Enter=改行、Ctrl+Enter=送信
; 日本語の変換中の Enter は、そのまま確定に使う
; 引数で対象の窓を差し替えられる（試験用）
target := A_Args.Length ? A_Args[1] : "ahk_exe claude.exe"
DetectHiddenWindows True

; Microsoft IME は、スペースで変換した後や Esc で候補を閉じた後は候補の窓を出さない。
; その間も変換中なので、変換のキーを押したことを覚えておく。
converting := false

ih := InputHook("L0 V")
ih.MinSendLevel := 1
ih.KeyOpt("{All}", "N")
ih.OnKeyDown := OnKey
ih.Start()

OnKey(ih, vk, sc) {
    global converting
    if !WinActive(target)
        return converting := false
    switch vk {
        case 0x0D, 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C:
            return                                   ; Enter と修飾キーは数えない
        case 0x20, 0x1C, 0x75, 0x76, 0x77, 0x78, 0x79:
            converting := Composing()                ; Space・変換・F6〜F10
        case 0x1B:
            converting := CandidateVisible()         ; Esc: 候補を閉じただけなら変換中のまま
        case 0x23, 0x24, 0x25, 0x26, 0x27, 0x28:
            return                                   ; 矢印・Home・End は文節の移動・候補の選択
        default:
            converting := false
    }
}

; 候補の窓（Microsoft IME の mscandui*.candidate）が手前の窓のプロセスに見えているか
CandidateVisible() {
    pid := WinGetPID("A")
    for h in WinGetList("ahk_pid " pid)
        if WinGetClass(h) ~= "^mscandui\d+\.candidate$" && DllCall("IsWindowVisible", "Ptr", h)
            return true
    return false
}
Composing() => CandidateVisible() || converting

; 変換中と見分けられなかったときは Shift+Enter になり、IME が無視するので送信はされない
#HotIf WinActive(target)
Enter::
NumpadEnter:: {
    global converting
    if Composing() {
        converting := false
        Send "{Enter}"
    } else
        Send "+{Enter}"
}
; Ctrl を指で離してから Enter を送る。先に送ると Ctrl を押し直すことになり、
; Ctrl 2回で動く常駐ソフト（Clibor など）が反応する
^Enter::
^NumpadEnter:: {
    global converting
    converting := false
    KeyWait "Ctrl", "L"
    Send "{Enter}"
}
~LButton::
~RButton:: {
    global converting
    converting := false
}
#HotIf

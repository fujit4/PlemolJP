# ini から VERSION を取得
$ini = Get-Content .\build.ini
$version = ($ini | Select-String -Pattern "VERSION").ToString().Split("=")[1].Trim()

# スクリプトファイルがある場所に移動する
Set-Location -Path $PSScriptRoot
# 各ファイルを置くフォルダを作成
New-Item -ItemType Directory -Force -Path ".\release_files\"
# ビルドフォルダを削除
Remove-Item -Path .\build -Recurse -Force

# 並列処理内で、処理が重いNerd Fontsのビルドを優先して処理する
$option_and_output_folder = @(
    @("--hidden-zenkaku-space --nerd-font  --boxhf ", "BoxHFNFHS-") # ビルド 罫線半角版全角スペース不可視+Nerd
)

$option_and_output_folder | Foreach-Object -ThrottleLimit 4 -Parallel {
    Write-Host "fontforge script start. option: `"$($_[0])`""
    Invoke-Expression "& `"C:\FontForge\FontForgeBuilds\bin\ffpython.exe`" .\fontforge_script.py --do-not-delete-build-dir $($_[0])" `
        && Write-Host "fonttools script start. option: `"$($_[1])`"" `
        && python fonttools_script.py $_[1]
}

$move_file_src_dest = @(
    @("PlemolJP*BoxHFNFHS*-*.ttf", "PlemolJP_NF_$version", "BoxHFNFHS"),
)

$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$move_dir = ".\release_files\build_$timestamp"

$move_file_src_dest | Foreach-Object {
    $folder_path = "$move_dir\$($_[1])"
    New-Item -ItemType Directory -Force -Path $folder_path
    Move-Item -Path ".\build\$($_[0])" -Destination $folder_path -Force

    $variant = ""
    if ($_[2] -ne "") {
        $variant = "_$($_[2])"
    }
    @(
        @("*BoxHFNFHS*.ttf", "PlemolJPBoxHFNFHS($variant)")
    ) | Foreach-Object {
        $individual_folder_path = "$folder_path\$($_[1])"
        # ファイル件数が0件の場合はフォルダを作成しない
        if ((Get-ChildItem -Path $folder_path\$($_[0])).Count -eq 0) {
            return
        }
        New-Item -ItemType Directory -Force -Path $individual_folder_path
        Move-Item -Path $folder_path\$($_[0]) -Destination $individual_folder_path -Force
    }
}


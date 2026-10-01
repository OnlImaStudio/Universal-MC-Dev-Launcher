# Universal MC Dev Launcher — V1.0

## English

Version: **V1.0**

### Purpose

Universal MC Dev Launcher (UMDL) is a lightweight Windows launcher for Minecraft Java Gradle development projects. It detects NeoForge, Forge, and Fabric projects; it does not manage Microsoft accounts, ordinary `.minecraft` installations, or the official launcher.

### Start

Double-click `UMDL.exe`. The GUI starts without a Command Prompt or PowerShell window. If startup fails, a readable error dialog is shown and the original details are written to `runtime/startup-error.log`.

### Scan and run

Use **Add scan folder** to add one or more roots. A newly added root is scanned by itself when automatic scanning is enabled; **Rescan** checks every remembered root. The project list shows the project name, Minecraft version, development environment, loader version, Java status, and launch status. Select a project to start its detected client task, view Gradle tasks, clean and rebuild, or build. Every Gradle command runs in the selected project root.

### Appearance and logs

Settings and **Log / Terminal** are pages inside the same main window. Dark/light themes, eight accent colors, six languages, background image, blur, card opacity, and Boolean options are saved immediately. Card opacity affects surfaces only while a background image is set; without one, surfaces stay fully opaque. Background images preserve their aspect ratio and cover the window. The log page shows the real command, task state, captured stdout/stderr, and provides copy, clear-view, and stop-current-task controls.

### Files and requirements

`ProjectScanner.ps1` performs project detection, `GradleRunner.ps1` runs Gradle in the selected root, and `languages.json` contains all visible translations. The launcher uses Windows PowerShell 5.1 and WPF, which are included with supported Windows 10/11 installations. Configuration, logs, runtime files, and assets remain inside this folder.









## Español

Versión: **V1.0**

### Objetivo

Universal MC Dev Launcher (UMDL) es una herramienta ligera para Windows que inicia proyectos de desarrollo de Minecraft Java basados en Gradle. Detecta proyectos NeoForge, Forge y Fabric; no administra cuentas de Microsoft, instalaciones normales de `.minecraft` ni el iniciador oficial.

### Inicio

Haz doble clic en `UMDL.exe`. La interfaz se abre sin una ventana de Símbolo del sistema ni PowerShell. Si el inicio falla, aparece un mensaje legible y los detalles originales se guardan en `runtime/startup-error.log`.

### Búsqueda y ejecución

Usa **Añadir carpeta de búsqueda** para agregar una o más raíces. Si la búsqueda automática está activada, una carpeta nueva se analiza por separado; **Volver a buscar** comprueba todas las raíces recordadas. La lista muestra el nombre, la versión de Minecraft, el entorno de desarrollo, la versión del cargador, el estado de Java y si se puede iniciar. Selecciona un proyecto para iniciar la tarea de cliente detectada, ver las tareas de Gradle, limpiar y recompilar, o compilar. Cada comando Gradle se ejecuta en la raíz del proyecto seleccionado.

### Apariencia y registros

Los ajustes y **Registro / Terminal** son páginas dentro de la misma ventana principal. Los temas claro/oscuro, ocho colores de acento, seis idiomas, la imagen de fondo, el desenfoque, la opacidad de las tarjetas y las opciones booleanas se guardan al instante. La opacidad de las tarjetas solo se aplica cuando hay una imagen de fondo; sin ella, las superficies son totalmente opacas. La imagen conserva su proporción y cubre la ventana. La página de registro muestra el comando real, el estado, stdout/stderr y controles para copiar, limpiar la vista o detener la tarea actual.

### Archivos y requisitos

`ProjectScanner.ps1` detecta proyectos, `GradleRunner.ps1` ejecuta Gradle en la raíz seleccionada y `languages.json` contiene todos los textos visibles. La herramienta usa Windows PowerShell 5.1 y WPF, incluidos en instalaciones compatibles de Windows 10/11. La configuración, los registros, los archivos temporales y los recursos permanecen dentro de esta carpeta.









## 日本語

バージョン：**V1.0**

### 目的

Universal MC Dev Launcher（UMDL）は、Minecraft Java の Gradle 開発プロジェクト向けの軽量な Windows ランチャーです。NeoForge、Forge、Fabric を判別します。Microsoft アカウント、通常の `.minecraft`、公式ランチャーは扱いません。

### 起動

`UMDL.exe` をダブルクリックしてください。コマンドプロンプトや PowerShell の黒いウィンドウを表示せずに GUI が起動します。起動に失敗した場合は内容を確認できるダイアログが表示され、元の詳細は `runtime/startup-error.log` に保存されます。

### スキャンと実行

**スキャンフォルダーを追加**で複数のルートを登録できます。自動スキャンが有効な場合、新しく追加したルートだけをスキャンし、**再スキャン**は登録済みの全ルートを確認します。プロジェクト名、Minecraft バージョン、開発環境、ローダーバージョン、Java の状態、起動可否を一覧表示します。プロジェクトを選択すると、検出されたクライアントタスクの起動、Gradle タスクの表示、クリーン再ビルド、ビルドを実行できます。すべての Gradle コマンドは選択したプロジェクトのルートで実行されます。

### 外観とログ

設定と **ログ / ターミナル**は、同じメインウィンドウ内のページとして切り替わります。ダーク/ライトテーマ、8 色の強調色、6 言語、背景画像、ぼかし、カードの不透明度、各オン/オフ設定はすぐに保存されます。カードの不透明度は背景画像が設定されている場合だけ反映され、背景画像がない場合は完全に不透明になります。背景画像は縦横比を保ったままウィンドウ全体を覆います。ログページには実際のコマンド、状態、stdout/stderr、コピー、表示クリア、現在のタスク停止を表示します。

### ファイルと動作条件

`ProjectScanner.ps1` がプロジェクトを検出し、`GradleRunner.ps1` が選択したルートで Gradle を実行し、`languages.json` が全表示言語を保持します。対応する Windows 10/11 に標準搭載される Windows PowerShell 5.1 と WPF を使用します。設定、ログ、実行時ファイル、画像素材はすべてこのフォルダー内に保存されます。









## 한국어

버전: **V1.0**

### 용도

Universal MC Dev Launcher(UMDL)는 Minecraft Java Gradle 개발 프로젝트를 위한 가벼운 Windows 런처입니다. NeoForge, Forge, Fabric 프로젝트를 감지하며 Microsoft 계정, 일반 `.minecraft`, 공식 런처는 관리하지 않습니다.

### 시작

`UMDL.exe`를 두 번 클릭하세요. 명령 프롬프트나 PowerShell 검은 창 없이 GUI가 시작됩니다. 시작에 실패하면 읽을 수 있는 오류 창이 표시되고 원본 세부 정보는 `runtime/startup-error.log`에 저장됩니다.

### 스캔과 실행

**스캔 폴더 추가**에서 하나 이상의 루트를 등록할 수 있습니다. 자동 스캔을 켜면 새로 추가한 루트만 스캔하고, **다시 스캔**은 기억된 모든 루트를 확인합니다. 프로젝트 이름, Minecraft 버전, 개발 환경, 로더 버전, Java 상태, 실행 가능 상태를 표시합니다. 프로젝트를 선택하면 감지된 클라이언트 작업 실행, Gradle 작업 보기, 정리 후 다시 빌드, 빌드를 수행할 수 있습니다. 모든 Gradle 명령은 현재 선택한 프로젝트 루트에서 실행됩니다.

### 화면과 로그

설정과 **로그 / 터미널**은 같은 메인 창 안의 페이지로 전환됩니다. 다크/라이트 테마, 강조색 8개, 언어 6개, 배경 이미지, 흐림, 카드 불투명도, 각 켜기/끄기 옵션이 즉시 저장됩니다. 카드 불투명도는 배경 이미지가 설정된 경우에만 적용되며, 배경 이미지가 없으면 모든 표면이 완전히 불투명하게 유지됩니다. 배경 이미지는 비율을 유지한 채 창을 채웁니다. 로그 페이지에는 실제 명령, 상태, stdout/stderr, 복사, 표시 지우기, 현재 작업 중지 기능이 있습니다.

### 파일과 요구 사항

`ProjectScanner.ps1`는 프로젝트를 감지하고, `GradleRunner.ps1`는 선택한 루트에서 Gradle을 실행하며, `languages.json`에는 모든 사용자 표시 문구가 들어 있습니다. 지원되는 Windows 10/11에 포함된 Windows PowerShell 5.1과 WPF를 사용합니다. 설정, 로그, 런타임 파일, 이미지 리소스는 모두 이 폴더 안에 보관됩니다.









## 繁體中文

版本：**V1.0**

### 用途

Universal MC Dev Launcher（UMDL）是一個輕量的 Windows「Minecraft Java Gradle 開發專案」啟動工具，可識別 NeoForge、Forge、Fabric；不處理 Microsoft 帳號、一般 `.minecraft` 或官方啟動器。

### 啟動

雙擊 `UMDL.exe`。GUI 會直接開啟，不附帶命令提示字元或 PowerShell 黑色視窗。若啟動失敗，程式會顯示可閱讀的錯誤訊息，原始細節會寫入 `runtime/startup-error.log`。

### 掃描與執行

使用「新增掃描資料夾」加入一個或多個根目錄。自動掃描開啟時只掃描剛加入的新目錄；「重新掃描」才會檢查全部已記住的根目錄。清單會顯示專案名稱、Minecraft 版本、開發環境、載入器版本、Java 狀態與能否啟動。選取專案後可啟動偵測到的客戶端工作、查看 Gradle 工作、清理並重新建置或建置專案。所有 Gradle 命令都會在目前選取的專案根目錄執行。

### 外觀與日誌

設定與「日誌 / 終端」都是同一個主視窗內的頁面。黑夜/白天主題、8 種強調色、6 種語言、背景圖片、模糊度、卡片不透明度與各開關會立即儲存。卡片不透明度只在設定背景圖片時生效；沒有背景圖片時，所有介面表面保持完全不透明。背景圖片保持比例覆蓋視窗。日誌頁顯示真實命令、狀態、stdout/stderr，並提供複製、清空顯示與停止目前工作。

### 檔案與需求

`ProjectScanner.ps1` 負責偵測專案，`GradleRunner.ps1` 在選定根目錄執行 Gradle，`languages.json` 保存全部介面翻譯。程式使用支援的 Windows 10/11 內建之 Windows PowerShell 5.1 與 WPF。設定、日誌、執行時檔案與圖片資源都保存在本資料夾內。









## 简体中文

版本：**V1.0**

### 用途

Universal MC Dev Launcher（UMDL）是一个轻量的 Windows“Minecraft Java Gradle 开发项目”启动工具，可识别 NeoForge、Forge、Fabric；不处理 Microsoft 账号、普通 `.minecraft` 或正版启动器。

### 启动

双击 `UMDL.exe`。GUI 会直接打开，不附带 CMD 或 PowerShell 黑窗口。启动失败时会显示可读的错误对话框，原始详情写入 `runtime/startup-error.log`。

### 扫描与运行

使用“添加扫描文件夹”加入一个或多个根目录。自动扫描开启时只扫描刚加入的新目录；“重新扫描”才检查全部已记住的根目录。列表显示项目名、Minecraft 版本、开发环境、加载器版本、Java 状态和可启动状态。选择项目后可以启动检测到的客户端任务、查看 Gradle 任务、清理并重新构建或构建项目。所有 Gradle 命令都在当前选择的项目根目录运行。

### 外观与日志

设置和“查看日志 / 终端”都是同一主窗口内的页面。黑夜/白天主题、8 种强调色、6 种语言、背景图片、模糊度、卡片不透明度和各个布尔开关会立即保存。卡片不透明度只在设置背景图片时生效；没有背景图片时，所有界面表面保持完全不透明。背景图片保持比例覆盖窗口。日志页显示真实命令、状态、stdout/stderr，并提供复制、清空显示和停止当前任务。

### 文件与要求

`ProjectScanner.ps1` 负责检测项目，`GradleRunner.ps1` 在选中根目录执行 Gradle，`languages.json` 保存全部界面翻译。程序使用受支持 Windows 10/11 自带的 Windows PowerShell 5.1 和 WPF。配置、日志、运行时文件和图片资源全部保存在本文件夹内。

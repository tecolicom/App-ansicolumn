# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

App-ansicolumnは、ANSI端末シーケンスを認識できるcolumnコマンド（ansicolumn）を提供するPerlアプリケーションです。Unix `column(1)` コマンドのクローンで、ANSIエスケープシーケンス、バックスペース、アジア圏のワイド文字を扱うことができます。従来のcolumnコマンドのオプションに加え、マルチカラムレイアウト、テーブル整形、ドキュメント表示、複数ファイルの並列表示など多数の拡張機能を持ちます。

## ビルドシステム

このプロジェクトは**Minilla**をビルドシステムとして使用しています（Perlモジュール作成ツール）。

- `Build.PL`はMinillaによって自動生成される - 直接編集しないこと
- ビルド方法: `perl Build.PL && ./Build`
- 注意: MSWin32は明示的にサポート外（Build.PLでdieする）

## テスト実行

テストの実行:
```bash
prove -lrv t
```

個別のテストファイル:
```bash
prove -lv t/01_run.t
```

テスト構造:
- `t/00_compile.t` - コンパイルテスト
- `t/01_run.t` - Data::Section::Simpleを使用した基本的な機能テスト
- `t/02_yamanashi.t` - 追加テスト
- `t/ac.pm` - テストオブジェクトを作成するヘルパーモジュール
- `t/home/.ansicolumnrc` - テスト用設定ファイル

## 依存関係

依存関係のインストール:
```bash
cpanm --installdeps .
```

主要なランタイム依存関係（cpanfileより）:
- Getopt::EX (v2.2.1+) - モジュールローディング機能を持つ拡張可能なオプションフレームワーク
- Getopt::EX::Hashed (1.06+) - ハッシュベースのオプション宣言
- Getopt::EX::RPN (0.01+) - オプション値のRPN計算機
- Text::ANSI::Fold (2.29+) - ANSI対応テキスト折り返し
- Text::ANSI::Printf (2.07+) - ANSI対応printf
- Term::ANSIColor::Concise (2.08+) - 色指定
- Math::RPN - RPN式評価
- Clone - オブジェクトのクローン

## コードアーキテクチャ

### 主要コンポーネント

1. **lib/App/ansicolumn.pm** - メインアプリケーションモジュール
   - Getopt::EX::Hashedを使用した宣言的なオプション定義
   - ExConfigureでBASECLASSを設定し、Getopt::EXモジュールローディングを有効化
   - `has` DSLでオプション定義（例: `has width => ' =s w c '`）
   - カラムレイアウトとフォーマッティングのメイン実行ロジック

2. **lib/App/ansicolumn/Util.pm** - ユーティリティ関数
   - 端末サイズ取得、テキスト操作、転置などのヘルパーメソッド
   - `terminal_size()` - Term::ReadKeyで端末サイズを取得
   - `xpose()` - 2次元配列の転置
   - `roundup()`, `div()` - レイアウト計算用の数学ヘルパー
   - テキスト折り返しとレイアウトヘルパー（foldobj, foldsub）

3. **lib/App/ansicolumn/Border.pm** - ボーダースタイルシステム
   - マルチペイン出力の装飾的な枠線を管理
   - `add_style()` クラスメソッドで新しいボーダースタイルを登録
   - 各スタイルは right, center, left, top, bottom の要素を持つ
   - 豊富な定義済みスタイル（box, frame, shadow など）

4. **lib/App/ansicolumn/default.pm** - デフォルトオプションエイリアス
   - `--white-board`, `--black-board` などの便利オプションを定義
   - __DATA__セクションでGetopt::EXの`option`ディレクティブを使用
   - カスタムボーダースタイル（star, square）

5. **script/ansicolumn** - コマンドラインエントリポイント

### オプションシステム

**Getopt::EX**フレームワークを使用しており、以下の機能を提供:
- `-M`オプションによるモジュールローディング
- 起動ファイルのサポート（`~/.ansicolumnrc`）
- __DATA__セクションでのオプションエイリアス定義
- オプション値でのRPN式評価（例: `--height 1-2/` は (height-1)/2 を意味）

### 主要な設計パターン

- **Getopt::EX::Hashed**: すべてのオプションを has() DSL で宣言、自動的にgetter/setterを生成
- **テキスト折り返し**: ANSIシーケンスを考慮した幅認識テキスト折り返しにText::ANSI::Foldを使用
- **レイアウトエンジン**: ペイン幅を計算し、ボーダーを適用、ページネーションとfillupを処理
- **拡張性**: ボーダースタイルは add_style() で追加可能、オプションは .ansicolumnrc で追加可能

## 設定ファイル

ユーザーは `~/.ansicolumnrc` を作成してデフォルトオプションを設定したり、カスタム機能を定義できます:

```perl
# デフォルトオプションの設定
option default --no-white-space

# カスタムボーダースタイルの定義
__PERL__
App::ansicolumn::Border->add_style(
    mystyle => {
        left   => "< ",
        center => "| ",
        right  => " >",
    },
);
```

## モジュールローディングシステム

`-M`オプションでGetopt::EXモジュールをロード:
```bash
ansicolumn -Mfoo  # App::ansicolumn::foo または Getopt::EX::foo をロード
```

これによりコアコードを変更せずに機能を拡張できます。

## CI/CD

GitHub Actionsワークフロー（`.github/workflows/test.yml`）:
- push、PR、手動実行時にテスト
- Perlバージョン: 5.40, 5.38, 5.30, 5.28, 5.18, 5.16
- `prove -lrv t` を実行

## バージョン管理

- バージョンは `lib/App/ansicolumn.pm` の `$VERSION` で定義
- Minillaがバージョニングとリリースプロセスを管理
- 現在のバージョン: 1.45

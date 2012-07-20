## ᚲᛟᛒᛟ

Kobo にファイルを転送し、ついでに本棚を自動生成します。


## 使いかた

以下のように引数を4つ与えます。

     kobo-auto-shelf.rb \
       /mnt/kobo/body \
       /mnt/kobo/sd \
       /media/data/device/kobo/body \
       /media/data/device/kobo/sd

各引数の意味は下の通りです

1. Kobo の本体ストレージのパス
2. Kobo のSDストレージのパス
3. 本体へ転送したいファイルのあるディレクトリ
4. SD へ転送したいファイルのあるディレクトリ


これで、ファイルが転送され、本棚情報が書きこまれます。


## ディレクトリ形式

引数の後半二つのディレクトリは、以下のように
<本棚名>/ファイル のように一つだけディレクトリを作ってそこへ入れます。


    ├── vimpr
    │   ├── [anekos] Happy Hacking Vimperator.epub
    │   └── [anekos616] 獄門 Vimperator.epub
    ├── vim
    │   ├── [しょうご] 小学生ではわからないかもしれない Vim.epub
    │   └── [まんぼう] 水銀.epub
    └── xmonad
        ├── [えっきすもな堂] えっきすモナ道.epub
        └── [anekos] おれおれ conf.epub

## Requirements

Ruby1.9
sqlite3-ruby

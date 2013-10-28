**un_used_module.pl**
=================

Description
-----------

un_used_module.pl - print use list which used and do not write use module declaration in perl code.


Installation
============

```
git clone https://github.com/nakatakeshi/un_used_module.pl
cd un_used_module.pl
carton install
```

How to use
============
if you want to show use list which donot use declaration in `/path/to/perlfile`
```
carton exec -- perl bin/un_used_module.pl --file /path/to/perlfile --additional_lib=/path/to/additional/lib
```

if you are vim user add this line to your .vimrc
```vim
" package-adder
function! PackageAdder()
    exe ":1"
    exe "?^use .*;$?"
    let cmd =  'cd /path/to/bin/un_used_module.pl;carton exec -- perl /path/to/bin/un_used_module.pl/bin/un_used_module.pl --additional_lib=/path/to/additional/lib1,/path/to/additional/lib2 --file ' . expand("%:p")
    let use_string = split(system(cmd),"\n",1)
    let currow = getpos(".")[1]
    call append(currow, use_string)
endfunction
nnoremap ,pa :<C-u>call PackageAdder()<CR>
```
this setting enable to add use list to your current buffer perl file.

* caution
this vim setting check saved current perl file. so you need save current buffer perl file before run this script.

Caution
============
if your perl file include like this code
```perl
Packagename->require;
```
then you need not write `use Packagename;` but this script output `use Packagename;`

#!/bin/bash
# Print an junisor size rollabindable album from shotwell collections.
# Requires sqlite3, gnu rec-utils, netpbm, and pdftex.
# Currently supports only jpeg.

if [ ${#@} != 1 ]; then
  echo "Usage: `basename $0` <shotwell-tag>"
  exit 
fi


TITLE="Rich's Shotwell Album"
AUTHOR="Rich Traube"
SHOTWELLDB=$HOME/.shotwell/data/photo.db
TAG="$1"
RECFILE=photos.rec
RESCALETEMPLATE=rescale.fmt
RESCALESCRIPT=rescale.sh
PHOTODIR=photos
LISTTEMPLATE=photos.fmt
TEXLIST=photos.tex
ALBUM=album.tex
TEXCOM=pdflatex

rm -f $TEXLIST


if [ ! -d $PHOTODIR ]; then
	mkdir $PHOTODIR
fi



# Start recutils file.
cat<<EOT> $RECFILE
%rec: photo
%key: filename
%sort: exposure_time
EOT

sqlite3  $SHOTWELLDB '
	SELECT photo_id_list FROM TagTable WHERE name = "'${TAG}'";
' | awk '
	BEGIN { FS=","}
	{
		for (i=1;i<NF;i++) {
			sub("thumb","0x",$i); print strtonum($i);
		}
	}
' | xargs -I{} sqlite3 -line $SHOTWELLDB '
	SELECT filename, exposure_time, title FROM PhotoTable WHERE id="'{}'"
' | awk '
{
	sub(/^\ */,"");
	sub(/ = /,": ");

	if (/^filename: /) {
		spfile = $0;
		sub(/^filename: /,"",spfile);
		gsub(/\//,"_",spfile);
		gsub(/ /,"_",spfile);
		gsub(/\(/,"",spfile);
		gsub(/\)/,"",spfile);
		sp1 = "spfile: " spfile;
		sub(": ",": \"",$0);
		sub(/$/,"\"",$0);
		print "\n" $0;
		next; 
	}
	if (/^exposure_time: /) {
		time = $0;
		sub(/^exposure_time: /,"",time);
		sp2 = "sptime: " strftime("%a %x",time);
		print;
		next;
	}
		print;
		print sp1;
		print sp2;
}' >> $RECFILE


if [ ! -f $LISTTEMPLATE ]; then
cat<<EOT > $LISTTEMPLATE
\addtocounter{figs}{1}
\begin{SCfigure*}
\includegraphics{$PHOTODIR/{{spfile}}}
\caption*{ {{title}} \it{ {{sptime}} }}
\end{SCfigure*}
\ifthenelse{\equal{ \intcalcMod{\value{figs}}{2}}{0}}
{\thispagestyle{empty}\clearpage}
{}
EOT
fi


recsel $RECFILE | recfmt -f $LISTTEMPLATE > $TEXLIST


if [ -z $(cat $TEXLIST) ]; then
	echo "$TAG not found in shotwell tag table."
	exit
fi

# Template for scaling script.
if [ ! -f $RESCALETEMPLATE ]; then
	cat<<-EOT> $RESCALETEMPLATE
if [ ! -f "$PHOTODIR/{{spfile}}" ]; then
	jpegtopnm {{filename}} \
	| pnmscale -ysize 350 \
	| pnmtojpeg -quality=100 -progressive \
	> "$PHOTODIR/{{spfile}}"
fi
EOT
fi

recsel $RECFILE | recfmt -f "$RESCALETEMPLATE" >> $RESCALESCRIPT
. $RESCALESCRIPT

if [ ! -f $ALBUM ]; then
cat<<EOT > $ALBUM
\documentclass[letterpaper]{article}
\usepackage{graphicx}
\usepackage{caption}
\usepackage{xifthen}
\usepackage{intcalc} % Use intcalcMod 2 0 to clear page very two images.
\newcounter{figs}
\usepackage[right=.25in,left=.125in,top=.25in,bottom=.50in]{geometry}
\usepackage[rightcaption,ragged]{sidecap}
\title{$TITLE}
\author{$AUTHOR}
\pagestyle{empty}
\begin{document}
\maketitle
\thispagestyle{empty}
\newpage

\input{$TEXLIST}


\end{document}
EOT
fi

$TEXCOM $ALBUM


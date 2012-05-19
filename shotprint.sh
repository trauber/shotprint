#!/bin/bash
#    shotprint - Print a junior size rollabindable album from shotwell tag.
#    Copyright (C) 2012  Rich Traube
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    Contacts: rich.traube@gmail.com
#
#    Rich Traube
#    2 Mindy Drive
#    Moorestown, NJ 08057

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
ROTNRESTEMPLATE=rotnres.fmt
ROTNRESSCRIPT=rotnres.sh
LISTTEMPLATE=photos.fmt
TEXLIST=photos.tex
ALBUM=album.tex
TEXCOM=pdflatex


if [ ! -d $PHOTODIR ]; then
	mkdir $PHOTODIR
fi

############## TEMPLATES ##################################


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

# Template for rotating and rescaling

if [ ! -f $ROTNRESTEMPLATE ]; then
	cat<<-EOT> $ROTNRESTEMPLATE
if [ ! -f "$PHOTODIR/{{spfile}}" ]; then
	cp {{filename}} tmp.jpg
	rotate -r 90 tmp.jpg
	jpegtopnm tmp.jpg \
	| pnmscale -ysize 350 \
	| pnmtojpeg -quality=100 -progressive \
	> "$PHOTODIR/{{spfile}}"
fi
EOT
fi
		
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

############# /TEMPLATES ##################################


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
	SELECT filename, orientation, exposure_time, title FROM PhotoTable WHERE id="'{}'"
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
		print sp1;
		next; 
	}
	if (/^exposure_time: /) {
		time = $0;
		sub(/^exposure_time: /,"",time);
		sp2 = "sptime: " strftime("%a %x",time);
		print;
		print sp2;
		next;
	}
		print;
}' >> $RECFILE


#rm -f $TEXLIST

recsel $RECFILE | recfmt -f $LISTTEMPLATE > $TEXLIST

if [ -z "$(cat $TEXLIST)" ]; then
	echo "$TAG not found in shotwell tag table."
	exit
fi


recsel -e 'orientation="6"' $RECFILE | recfmt -f "$ROTNRESTEMPLATE" > $ROTNRESSCRIPT
. $ROTNRESSCRIPT

recsel $RECFILE | recfmt -f "$RESCALETEMPLATE" > $RESCALESCRIPT
. $RESCALESCRIPT

$TEXCOM $ALBUM


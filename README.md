## shotprint

shotprint is a bash/awk script for printing junior size rollabindable
photo albums from a Shotwell collection.  It requires sqlite3, gnu
rec-utils, netpbm, and pdftex.

	usage: shotprint <shotwell-tag>

Run it in an empty directory outside of your shotwell hierarchy.
It currently supports jpeg only.  LaTeX sources written to file, not
to stdout.  pdflatex produces the output.



#!/bin/bash
. $(dirname $0)/env.sh

echo DART_DOCGEN=$DART_DOCGEN
ls -l "$DART_DOCGEN" || true
echo DARTDOC=$DARTDOC
ls -l "$DARTDOC" || true

# Temporary during transition period from use of dartdoc to docgen.
if [ -x "$DART_DOCGEN" ]; then
    DOC_CMD="$DART_DOCGEN"
    MODE_OPTION=
elif [ -x "$DARTDOC" ]; then
    DOC_CMD="$DARTDOC"
    MODE_OPTION="--mode=static"
else
    echo "There is no tool to generate the documentation!"
    echo "Report success during this transition period from dartdoc to docgen."
    exit 0;
fi

echo Generating documentation using $DOC_CMD using mode option '$MODE_OPTION'
"$DOC_CMD" $MODE_OPTION \
    --package-root=packages/ \
    --out doc \
    --exclude-lib=js,metadata,meta,mirrors,intl,number_symbols,number_symbol_data,intl_helpers,date_format_internal,date_symbols,angular.util \
    packages/angular/angular.dart lib/mock/module.dart



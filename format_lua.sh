#!/bin/sh

echo "Formatting lua files..."
find -name "*.lua" -exec lua-format -i {} ";"
echo "Finished!"


# image resizing code:

# number is pixel width, base line:
sips --resampleWidth 5000 input.jpg --out SML_output.jpg

for file in *.jpg; do
  sips --resampleWidth 5000 "$file" --out "SML_$file"
done
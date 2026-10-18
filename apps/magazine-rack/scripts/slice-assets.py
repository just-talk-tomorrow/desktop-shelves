from PIL import Image
from pathlib import Path
import argparse, json, os, shutil

parser = argparse.ArgumentParser(description='Slice editorial source sheets into transparent PNG assets.')
parser.add_argument('--source', help='Directory containing the original generated source-sheet PNG files.')
args = parser.parse_args()

root=Path(__file__).resolve().parents[1]
source_arg=args.source or os.environ.get('MAGAZINE_SOURCE_SHEETS')
source=Path(source_arg).expanduser() if source_arg else None
entries=[]
for prefix,filename,rows in [('sticker','exec-0542d0a5-87d9-4675-b4a7-0338e3f28f23.png',6),('paper','exec-c39f1b21-3e88-4e3b-98dc-67a06d54c18c.png',4),('american','exec-8289b283-d05a-498c-884a-afe79a5d0a93.png',6),('construct','exec-9ddeac53-ebe8-4d05-b71b-22c4c54e14f0.png',6)]:
 saved=root/'Resources'/'SourceSheets'/f'{prefix}-atlas.png'
 if saved.exists():
  origin=saved
 elif source is not None:
  origin=source/filename
 else:
  raise SystemExit('Missing source sheets. Pass --source DIR or set MAGAZINE_SOURCE_SHEETS.')
 image=Image.open(origin).convert('RGBA')
 if origin!=saved: shutil.copy2(origin,saved)
 for row in range(rows):
  for col in range(6):
   tile=image.crop((round(col*image.width/6),round(row*image.height/rows),round((col+1)*image.width/6),round((row+1)*image.height/rows)))
   alpha=tile.getchannel('A');box=alpha.point(lambda x:255 if x>24 else 0).getbbox()
   if box is None: raise ValueError('empty asset')
   box=(max(0,box[0]-3),max(0,box[1]-3),min(tile.width,box[2]+3),min(tile.height,box[3]+3))
   tile=tile.crop(box)
   name=f'{prefix}-{row*6+col+1:02}.png'
   tile.save(root/'Resources'/'EditorialAssets'/name)
   entries.append({'file':name,'width':tile.width,'height':tile.height})
(root/'Resources'/'EditorialAssets'/'catalog.json').write_text(json.dumps(entries,indent=2))
print(f'{len(entries)} transparent PNG assets sliced')

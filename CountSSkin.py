import os
import zipfile
import json
import argparse
import re

namere = re.compile(r"^\s*name = (.*)$", re.MULTILINE | re.IGNORECASE)

parser = argparse.ArgumentParser()
parser.add_argument('infolder', type=str)

args = parser.parse_args()
infolder = args.infolder

#infolder = "skinWads"
#files = [f for f in os.listdir(infolder) if os.path.isfile(os.path.join(infolder, f))]
#print(files)

files = []
for dirpath, dirnames, filenames in os.walk(infolder):
    files += [os.path.join(dirpath, i) for i in filenames]

skinnames = []
for fn in files:
    filename, extention = os.path.splitext(fn)
    if extention == ".wad":
        #print("File is wad")
        with open(fn, "rb") as f:
            f.seek(4)
            lumpcount = int.from_bytes(f.read(4), "little")
            dictloc = int.from_bytes(f.read(4), "little")
            f.seek(dictloc)
            skincount = 0
            for i in range(lumpcount):
                f.seek(8, 1)
                lumpname = f.read(8).decode("ascii").rstrip("\x00")
                if lumpname == "S_SKIN":
                    f.seek(-16, 1)
                    lumppos = int.from_bytes(f.read(4), "little")
                    lumplen = int.from_bytes(f.read(4), "little")
                    returnpos = f.seek(0, 1)+8
                    f.seek(lumppos)
                    lump = f.read(lumplen).decode("ascii")
                    skinnames.extend(namere.findall(lump))
                    f.seek(returnpos)
                    #skincount += 1

    elif extention == ".pk3":
        #print("File is pk3")
        zf = zipfile.ZipFile(fn, "r")
        for lumpinfo in zf.infolist():
            if "S_SKIN" in lumpinfo.filename:
                #print(lumpinfo.filename)
                #print("Found S_SKIN")
                with zf.open(lumpinfo) as sskin:
                    lump = sskin.read().decode("ascii")
                    skinnames.extend(namere.findall(lump))
                    #print(fn)
                    #print(lump)

out = []
for sn in skinnames:
    out.append(sn.rstrip("\r"))
print(json.dumps(out))
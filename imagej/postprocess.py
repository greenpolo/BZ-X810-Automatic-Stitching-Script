#@ Float xwidth
#@ String indir
#@ String outdir
#@ String pattern
#@ String metadataFile
""" ImageJ/Fiji Jython script to:
    1. Group individual channel TIFFs by base name
    2. Extract the correct color plane from each RGB export
    3. Build a multi-channel hyperstack
    4. Save as TIFF with separate channel planes
"""

# Imports
import os
import time
from ij import IJ, ImagePlus, ImageStack, CompositeImage
from ij.plugin import ChannelSplitter
from ij.measure import Calibration
from ij.io import FileSaver
from ij.process import Blitter, LUT
from java.awt import Color

# ...

def extractChannel(img, channelName):
    """ Extract the signal by taking the MAXIMUM intensity across R, G, B planes.
        This handles:
        - Blue-only DAPI (Red=0, Green=0, Blue=Data) -> Max=Data
        - White DAPI (Red=Data, Green=Data, Blue=Data) -> Max=Data
        - Grayscale (Red=Data, Green=Data, Blue=Data) -> Max=Data
        Using MAX prevents overflow (unlike ADD) and preserves full intensity.
    """
    if img.getType() != ImagePlus.COLOR_RGB:
        # Already 8-bit or 16-bit? Return as is.
        return img

    print "    [%s] Extracting signal via RGB MAX projection..." % channelName
    
    # Split RGB
    planes = ChannelSplitter.split(img)
    # planes[0]=Red, planes[1]=Green, planes[2]=Blue
    
    ipR = planes[0].getProcessor() # We will accumulate result in Red
    ipG = planes[1].getProcessor()
    ipB = planes[2].getProcessor()
    
    # Max(Red, Green)
    ipR.copyBits(ipG, 0, 0, Blitter.MAX)
    # Max(Result, Blue)
    ipR.copyBits(ipB, 0, 0, Blitter.MAX)
    
    result = ImagePlus(channelName, ipR)
    
    planes[0].close(); planes[1].close(); planes[2].close()
    return result


def buildHyperstack(channelImages, channelOrder):
    """ Build a multi-channel hyperstack and apply LUTs. """
    
    # Get dimensions
    firstCh = channelImages[channelOrder[0]]
    width = firstCh.getWidth()
    height = firstCh.getHeight()
    nChannels = len(channelOrder)
    
    # Sort channels
    sortedChannels = sorted(channelOrder, key=lambda ch: CHANNEL_CONFIG[ch]["order"])
    
    # Create Stack
    stack = ImageStack(width, height)
    for chName in sortedChannels:
        chImg = channelImages[chName]
        stack.addSlice(CHANNEL_CONFIG[chName]["name"], chImg.getProcessor())
    
    # Create ImagePlus from the stack
    merged = ImagePlus("merged", stack)
    
    # Set as hyperstack: nChannels channels, 1 Z-slice, 1 timeframe
    merged.setDimensions(nChannels, 1, 1)
    
    # The user specifically requested avoidance of "CompositeImage" (which overlays in ImageJ).
    # Return the raw ImagePlus stack. This renders as separate grayscale channels you scroll through.
    
    print "    Hyperstack created: %d x %d, %d channels" % (width, height, nChannels)
    return merged

# ---- Channel configuration ----
# "plane" = Which RGB plane to extract (0=Red, 1=Green, 2=Blue)
# "order" = Sort order for consistent channel stacking (DAPI first, then GFP, then RFP)
CHANNEL_CONFIG = {
    "dapi": {"plane": 2, "order": 0, "name": "DAPI"},
    "gfp":  {"plane": 1, "order": 1, "name": "GFP"},
    "rfp":  {"plane": 0, "order": 2, "name": "RFP"},
    "bf":   {"plane": -1, "order": 3, "name": "Brightfield"},
}

# ---- Auxiliary functions ----




def setSpatialCalibration(img, xwidth, unit="micron"):
    if xwidth <= 0:
        return
    pixelSize = xwidth / (1.0 * img.getWidth())
    cal = Calibration(img)
    cal.pixelWidth = pixelSize
    cal.pixelHeight = pixelSize
    cal.setUnit(unit)
    img.setCalibration(cal)


def readTextFile(filepath):
    text = ""
    try:
        fid = open(filepath)
        text = fid.read()
        fid.close()
    except:
        print "Warning: could not read metadata file: %s" % filepath
    return text


def appendMetadata(img, newHeader):
    oldHeader = img.getInfoProperty()
    if oldHeader is not None:
        newHeader = oldHeader + "\n" + newHeader
    img.setProperty("Info", newHeader)


def groupFilesByBase(directory, pattern):
    groups = {}
    groupOrder = []
    
    for f in sorted(os.listdir(directory)):
        if not f.endswith(pattern):
            continue
        
        nameNoExt = f[:f.rfind(".")]
        lastUnderscore = nameNoExt.rfind("_")
        if lastUnderscore < 0:
            print "Warning: skipping file with no channel suffix: %s" % f
            continue
        
        baseName = nameNoExt[:lastUnderscore]
        channelName = nameNoExt[lastUnderscore + 1:].lower()
        
        if channelName not in CHANNEL_CONFIG:
            print "Warning: unknown channel '%s' in file %s, skipping" % (channelName, f)
            continue
        
        fullPath = os.path.join(directory, f)
        
        if baseName not in groups:
            groups[baseName] = {}
            groupOrder.append(baseName)
        groups[baseName][channelName] = fullPath
    
    return groupOrder, groups





def saveHyperstackTiff(img, outputPath):
    """ Save hyperstack as multi-page TIFF using FileSaver (headless-safe) """
    if not outputPath.endswith(".tif"):
        outputPath = outputPath + ".tif"
    
    print "    Saving TIFF: %s" % outputPath
    
    fs = FileSaver(img)
    if img.getStackSize() > 1:
        fs.saveAsTiffStack(outputPath)
    else:
        fs.saveAsTiff(outputPath)
    
    print "    Saved successfully (%d pages)." % img.getStackSize()


# ---- Main ----
t0 = time.time()
print "#------------------------------------------------"
print "# Merging channels into multi-channel hyperstacks"
print "# Parameters:"
print "#    image width (um) = %g" % (xwidth)
print "#    file pattern = %s" % (pattern)
print "#    input dir  = %s" % (indir)
print "#    output dir = %s" % (outdir)
print "#    metadata file = %s" % (metadataFile)
print "#------------------------------------------------"

# Read metadata
metaText = readTextFile(metadataFile)
if metaText != "":
    print "# Metadata:"
    print metaText
    print "#------------------------------------------------"

# Create output directory
if not os.path.exists(outdir):
    os.makedirs(outdir)

# Group channel files by base name
groupOrder, groups = groupFilesByBase(indir, pattern)
print "# Found %d image group(s)" % len(groupOrder)

for baseName in groupOrder:
    channels = groups[baseName]
    print ""
    print "Processing group: %s (%d channels)" % (baseName, len(channels))
    
    # Open each channel and extract the correct color plane
    channelImages = {}
    channelOrder = []
    for chName in sorted(channels.keys()):
        filePath = channels[chName]
        print "    Opening %s: %s" % (chName, os.path.basename(filePath))
        img = IJ.openImage(filePath)
        if img is None:
            print "    ERROR: could not open %s" % filePath
            continue
        
        # Extract the correct color plane from RGB
        print "    Extracting %s plane..." % chName
        extracted = extractChannel(img, chName)
        channelImages[chName] = extracted
        channelOrder.append(chName)
        
        # Close original if we created a new image
        if extracted is not img:
            img.close()
    
    if len(channelImages) == 0:
        print "    No valid channel images, skipping group"
        continue
    
    # Build hyperstack manually (no RGBStackMerge)
    if len(channelImages) == 1:
        chName = channelOrder[0]
        merged = channelImages[chName]
        print "    Single channel, no merge needed"
    else:
        print "    Building %d-channel hyperstack..." % len(channelImages)
        merged = buildHyperstack(channelImages, channelOrder)
    
    # Set calibration
    setSpatialCalibration(merged, xwidth)
    
    # Append metadata
    if metaText != "":
        appendMetadata(merged, metaText)
    
    # Save as multi-page TIFF
    outputFile = os.path.join(outdir, baseName + ".tif")
    saveHyperstackTiff(merged, outputFile)
    
    # Close all images
    merged.close()
    for chName in channelOrder:
        try:
            channelImages[chName].close()
        except:
            pass
    
    print "    Done: %s" % baseName

# Done
t1 = time.time()
print ""
print "#------------------------------------------------"
print "# Completed processing: %gs" % (t1 - t0)
print "# Waiting for ImageJ to close ..."
print "#------------------------------------------------"
IJ.run("Quit")
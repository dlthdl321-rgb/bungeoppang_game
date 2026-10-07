param([string]$SourcePath,[string]$OriginalPath,[string]$DestinationPath)
Add-Type -AssemblyName System.Drawing
$sourceImage = [System.Drawing.Image]::FromFile($SourcePath)
$originalImage = [System.Drawing.Image]::FromFile($OriginalPath)
$imageWidth = $originalImage.Width
$imageHeight = $originalImage.Height
$originalImage.Dispose()
$targetBitmap = New-Object System.Drawing.Bitmap($imageWidth,$imageHeight,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphicsCanvas = [System.Drawing.Graphics]::FromImage($targetBitmap)
$graphicsCanvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphicsCanvas.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphicsCanvas.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphicsCanvas.DrawImage($sourceImage,0,0,$imageWidth,$imageHeight)
$graphicsCanvas.Dispose()
$sourceImage.Dispose()
$targetBitmap.Save($DestinationPath,[System.Drawing.Imaging.ImageFormat]::Png)
$targetBitmap.Dispose()

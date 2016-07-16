Deploy POSHOrigin_vSphere {
    By PSGalleryModule ToPSGallery {
        FromSource '.\POSHOrigin_vSphere'
        To 'PSGallery'
        WithOptions @{
            ApiKey = $env:PSGALLERY_API_KEY
        }
    }
}
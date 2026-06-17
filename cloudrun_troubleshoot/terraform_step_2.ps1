# --- SET VARIABLES (match to self) ---
$PROJECT = ""
$REGION  = ""          
$REPO    = "app-images"            
$IMAGE   = "web"                 
$TAG     = "latest"

$IMG_URI = "$REGION-docker.pkg.dev/$PROJECT/$REPO/${IMAGE}:$TAG"

# --- LOGIN AND CONFIGURE DOCKER FOR AR ---
gcloud auth configure-docker "$REGION-docker.pkg.dev" -q

# --- BUILD IMAGE (Dockerfile in current directory) ---
docker build -t $IMG_URI .

# --- PUSH TO REPO ---
docker push $IMG_URI

# --- (optional) AR VERIFICATION ---
gcloud artifacts docker images list "$REGION-docker.pkg.dev/$PROJECT/$REPO" --include-tags
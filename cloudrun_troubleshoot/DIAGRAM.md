# Infrastructure Diagram — Cloud Run with External HTTP(S) Load Balancer

```mermaid
flowchart TB
    subgraph Internet
        USER["User / Browser"]
    end

    subgraph GCP["Google Cloud Platform"]
        subgraph LB["External HTTP(S) Load Balancer"]
            GIP["Global Static IP<br/>google_compute_global_address"]
            FWD_HTTP["Forwarding Rule :80<br/>google_compute_global_forwarding_rule"]
            FWD_HTTPS["Forwarding Rule :443<br/>google_compute_global_forwarding_rule"]
            HTTP_PROXY["HTTP Proxy<br/>google_compute_target_http_proxy"]
            HTTPS_PROXY["HTTPS Proxy<br/>google_compute_target_https_proxy"]
            SSL["Managed SSL Certificate<br/>google_certificate_manager_certificate"]
            URLMAP["URL Map<br/>google_compute_url_map"]
            BACKEND["Backend Service<br/>google_compute_backend_service"]
            NEG["Serverless NEG<br/>google_compute_region_network_endpoint_group"]
        end

        subgraph CR["Cloud Run"]
            SERVICE["Cloud Run Service<br/>troubleshoot-gcp-web"]
            REV["Active Revision<br/>nginx:alpine on port 8080"]
            INST1["Instance 1"]
            INST2["Instance 2"]
            INSTN["Instance N<br/>max=5"]
        end

        subgraph IAM["IAM & Security"]
            SA["Service Account<br/>troubleshoot-gcp-run-sa"]
            IAM_AR["roles/artifactregistry.reader"]
            IAM_COMPUTE["roles/artifactregistry.reader<br/>Compute Engine Default SA"]
            IAM_PUBLIC["roles/run.invoker<br/>allUsers"]
        end

        subgraph AR["Artifact Registry"]
            REPO["Docker Repository<br/>app-images"]
            IMAGE["Container Image<br/>web:latest"]
        end

        subgraph NET["Networking (Optional)"]
            VPC["VPC Network"]
            SUBNET["Subnet"]
            CONNECTOR["VPC Access Connector"]
        end
    end

    USER -->|"HTTP :80"| GIP
    USER -->|"HTTPS :443"| GIP
    GIP --> FWD_HTTP
    GIP --> FWD_HTTPS
    FWD_HTTP --> HTTP_PROXY
    FWD_HTTPS --> HTTPS_PROXY
    HTTPS_PROXY --- SSL
    HTTP_PROXY --> URLMAP
    HTTPS_PROXY --> URLMAP
    URLMAP -->|"/* default route"| BACKEND
    BACKEND --> NEG
    NEG --> SERVICE

    SERVICE --> REV
    REV --> INST1
    REV --> INST2
    REV --> INSTN

    SA --> IAM_AR
    IAM_AR -->|"pull images"| REPO
    IAM_COMPUTE -->|"infra-level pull"| REPO
    IAM_PUBLIC -->|"invoke"| SERVICE
    REPO --> IMAGE
    IMAGE -.->|"deployed to"| REV

    CONNECTOR -.->|"optional egress"| SERVICE
    CONNECTOR --> SUBNET
    SUBNET --> VPC

    style GIP fill:#4285F4,color:#fff
    style SERVICE fill:#0F9D58,color:#fff
    style REPO fill:#F4B400,color:#000
    style SA fill:#DB4437,color:#fff
    style BACKEND fill:#4285F4,color:#fff
    style NEG fill:#4285F4,color:#fff
```

## Data Flow

1. **User** sends HTTP/HTTPS request to the **Global Static IP**
2. **Forwarding Rule** routes to the appropriate **HTTP/HTTPS Proxy**
3. **HTTPS Proxy** terminates TLS using the **Managed SSL Certificate**
4. **URL Map** routes all paths (`/*`) to the **Backend Service**
5. **Backend Service** forwards to the **Serverless NEG**
6. **Serverless NEG** routes to the **Cloud Run Service**
7. **Cloud Run** auto-scales instances (min=1, max=5) based on concurrency/RPS
8. Container images are pulled from **Artifact Registry** using IAM permissions granted to both the runtime SA and the Compute Engine default SA

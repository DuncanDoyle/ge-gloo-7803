# Gloo-7803 Reproducer


## Installation

Add Gloo EE Helm repo:
```
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
```

Export your Gloo Edge License Key to an environment variable:
```
export GLOO_EDGE_LICENSE_KEY={your license key}
```

Install Gloo Edge:
```
cd install
./install-gloo-edge-enterprise-with-helm.sh
```

> NOTE
> The Gloo Edge version that will be installed is set in a variable at the top of the `install/install-gloo-edge-enterprise-with-helm.sh` installation script.

## Setup the environment

Run the `install/setup.sh` script to setup the environment:
- Deploy Keycloak
- Deploy the VirtualServices
- Deploy the HTTPBin service
- Deploy the OAuth ExtAuth policy

```
./setup.sh
```

## Create an OAuth Client.

Run the `keycloak.sh` script to create an OAuth client in Keycloak. The script will return the client-id and client-secret needed to fetch an accesstoken for a Client Credentials Grant login flow.

```
./keycloak.sh
```

## Run the test

1. Fetch a an access-token from Keycloak using client-credentials grant flow and access the HTTPBin service. This request should be authorized and provide the valid response from upstream:

```
export CLIENT_ID={your client id}
export CLIENT_SECRET={your client secret}

export ACCESS_TOKEN=$(curl --request POST \
  --url 'http://keycloak.example.com/realms/master/protocol/openid-connect/token' \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data grant_type=client_credentials \
  --data client_id=$CLIENT_ID \
  --data client_secret=$CLIENT_SECRET | jq -r '.access_token')

curl -v -H "Authorization: Bearer $ACCESS_TOKEN" http://api.example.com/httpbin/get
```

2. Bring down Keycloak:
```
kubectl -n keycloak scale --replicas 0 deployment keycloak 
```

3. Restart the ExtAuth server:
```
kubectl -n gloo-system rollout restart deployment extauth && kubectl -n gloo-system rollout status deploy/extauth
```

When you now look at the logs, you will see that the ExtAuth server can't accesss Keycloak, and thus completely rejects the AuthConfig:

```
{"level":"info","ts":"2024-03-01T10:22:17.510Z","caller":"runner/xds.go:115","msg":"{\"auth_config_ref_name\":\"gloo-system.oauth-auth\",\"configs\":[{\"AuthConfig\":{\"Oauth2\":{\"OauthType\":{\"AccessTokenValidationConfig\":{\"ValidationType\":{\"Jwt\":{\"JwksSourceSpecifier\":{\"RemoteJwks\":{\"url\":\"http://keycloak.example.com/realms/master/protocol/openid-connect/certs\",\"refresh_interval\":{\"seconds\":10}}}}},\"ScopeValidation\":null}}}}}]}","version":"1.15.14"}
{"level":"error","ts":"2024-03-01T10:22:17.539Z","caller":"jwks/utils.go:24","msg":"failed to fetch JWKS","version":"1.15.14","error":"request failed with code 503 Service Unavailable","stacktrace":"github.com/solo-io/ext-auth-service/pkg/config/utils/jwks.FetchJwksWithClient\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/config/utils/jwks/utils.go:24\ngithub.com/solo-io/ext-auth-service/pkg/config/utils/jwks.FetchJwks\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/config/utils/jwks/utils.go:16\ngithub.com/solo-io/ext-auth-service/pkg/config/oauth/token_validation/jwt/jwks.NewRemoteJwksSource\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/config/oauth/token_validation/jwt/jwks/remote.go:71\ngithub.com/solo-io/ext-auth-service/pkg/config.(*authServiceFactory).NewOAuth2JwtAccessTokenAuthService\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/config/factory.go:318\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/config.(*extAuthConfigTranslator).authConfigToService\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/config/translator.go:310\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/config.(*extAuthConfigTranslator).getConfigs\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/config/translator.go:103\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/config.(*extAuthConfigTranslator).Translate\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/config/translator.go:87\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/config.(*configGenerator).GenerateConfig\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/config/generator.go:86\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run.func1.1\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:121\ngithub.com/solo-io/gloo/projects/gloo/pkg/api/v1/enterprise/options/extauth/v1.applyExtAuthConfig.func1\n\t/go/pkg/mod/github.com/solo-io/gloo@v1.15.23/projects/gloo/pkg/api/v1/enterprise/options/extauth/v1/ext_auth_discovery_service_xds.sk.go:111\ngithub.com/solo-io/solo-kit/pkg/api/v1/control-plane/client.(*client).Start\n\t/go/pkg/mod/github.com/solo-io/solo-kit@v0.33.0/pkg/api/v1/control-plane/client/client.go:137\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run.func1\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:148\ngithub.com/solo-io/go-utils/contextutils.(*exponentialBackoff).Backoff\n\t/go/pkg/mod/github.com/solo-io/go-utils@v0.24.6/contextutils/backoff.go:70\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:157\ngithub.com/solo-io/ext-auth-service/pkg/server.Server.Run.func3\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/server/server.go:160"}
{"level":"error","ts":"2024-03-01T10:22:17.541Z","caller":"config/generator.go:114","msg":"Errors encountered while processing new server configuration","version":"1.15.14","error":"1 error occurred:\n\t* failed to get auth service for auth config with id [gloo-system.oauth-auth]; this configuration will be ignored: failed to fetch JWKS: request failed with code 503 Service Unavailable\n\n","stacktrace":"github.com/solo-io/solo-projects/projects/extauth/pkg/config.(*configGenerator).GenerateConfig\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/config/generator.go:114\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run.func1.1\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:121\ngithub.com/solo-io/gloo/projects/gloo/pkg/api/v1/enterprise/options/extauth/v1.applyExtAuthConfig.func1\n\t/go/pkg/mod/github.com/solo-io/gloo@v1.15.23/projects/gloo/pkg/api/v1/enterprise/options/extauth/v1/ext_auth_discovery_service_xds.sk.go:111\ngithub.com/solo-io/solo-kit/pkg/api/v1/control-plane/client.(*client).Start\n\t/go/pkg/mod/github.com/solo-io/solo-kit@v0.33.0/pkg/api/v1/control-plane/client/client.go:137\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run.func1\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:148\ngithub.com/solo-io/go-utils/contextutils.(*exponentialBackoff).Backoff\n\t/go/pkg/mod/github.com/solo-io/go-utils@v0.24.6/contextutils/backoff.go:70\ngithub.com/solo-io/solo-projects/projects/extauth/pkg/runner.(*configSource).Run\n\t/go/src/github.com/solo-io/solo-projects/projects/extauth/pkg/runner/xds.go:157\ngithub.com/solo-io/ext-auth-service/pkg/server.Server.Run.func3\n\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.44.0-patch2/pkg/server/server.go:160"}
```

4. Bring Keycloak back up:
```
kubectl -n keycloak scale --replicas 1 deployment keycloak && kubectl -n keycloak rollout status deploy/keycloak
``` 

5. Try to access the HTTPBin service again:
```
export CLIENT_ID={your client id}
export CLIENT_SECRET={your client secret}

export ACCESS_TOKEN=$(curl --request POST \
  --url 'http://keycloak.example.com/realms/master/protocol/openid-connect/token' \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data grant_type=client_credentials \
  --data client_id=$CLIENT_ID \
  --data client_secret=$CLIENT_SECRET | jq -r '.access_token')

curl -v -H "Authorization: Bearer $ACCESS_TOKEN" http://api.example.com/httpbin/get
```

Note that you will now get a 403.

## Conclusinon
What happens is that the ExtAuth server refuses the `AuthConfig` when it can't access the `remoteJwks` URL when it tries to load the config. And since the `AuthConfig` is not loaded at all, the `refreshInterval` does not have any influence on JWKS refetching.

The only way to resolve this atm is to restart the ExtAuth server when the `remoteJwks` URL is reachable.

```
kubectl -n gloo-system rollout restart deployment extauth && kubectl -n gloo-system rollout status deploy/extauth
```
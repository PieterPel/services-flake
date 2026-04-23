# FalkorDB

[FalkorDB](https://www.falkordb.com/) is a graph database built on top of Redis. It exposes a Cypher-compatible query interface via the `GRAPH.*` Redis command family, making it compatible with any Redis client.

FalkorDB is distributed as a Redis module (a `.so` file), so the service runs a standard Redis server with the module loaded.

## Package

FalkorDB is not available in nixpkgs. You need to provide the package separately — for example via a dedicated `falkordb-flake` input:

```nix
# flake.nix
inputs.falkordb.url = "github:your-org/falkordb-flake";
```

Supported platforms: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.  
`x86_64-darwin` is not supported (no upstream binary available).

## Getting started

```nix
# Inside `process-compose.<name>`
{ inputs, ... }:
{
  services.falkordb."db1" = {
    enable = true;
    package = inputs.falkordb.packages.${system}.default;
  };
}
```

Connect with any Redis client on port `6379`, or query directly:

```bash
redis-cli GRAPH.QUERY mygraph "CREATE (:Person {name: 'Alice'})"
redis-cli GRAPH.QUERY mygraph "MATCH (p:Person) RETURN p.name"
```

## Configuration

```nix
services.falkordb."db1" = {
  enable = true;
  package = inputs.falkordb.packages.${system}.default;

  # Optional overrides
  bind = "127.0.0.1";  # null = all interfaces
  port = 6379;

  # Append extra Redis config directives
  extraConfig = ''
    maxmemory 512mb
    maxmemory-policy allkeys-lru
  '';
};
```

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/falkordb_test.nix>

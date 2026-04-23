{ pkgs, config, ... }: {
  services.falkordb."falkordb1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.falkordb."falkordb1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "falkordb-test";
        runtimeInputs = [ cfg.redisPackage pkgs.gnugrep ];
        text = ''
          echo "Ping FalkorDB (via Redis protocol)"
          redis-cli -p ${toString cfg.port} ping | grep -i "PONG"

          echo "Create a graph and run a query"
          redis-cli -p ${toString cfg.port} GRAPH.QUERY test "CREATE (:Node {name: 'hello'})" | grep -i "nodes_created"

          echo "Query the graph"
          redis-cli -p ${toString cfg.port} GRAPH.QUERY test "MATCH (n) RETURN n.name" | grep "hello"
        '';
      };
      depends_on."falkordb1".condition = "process_healthy";
    };
}

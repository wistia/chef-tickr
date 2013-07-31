# tickr cookbook

# Requirements

Your environment should contain a hash of node => number mappings like:

    'tickr' => {
      'node_number_mappings' => {
        'tickr-1' => 0,
        'tickr-2' => 1,
        'tickr-3' => 2
      }
    }

# Usage

Create a role using the 'tickr[::default]' cookbook. Be sure it defines
node[max_nodes] and node[starting_offset], neither of which should change
after you first go live. node[node_number] will be set automatically based on
your environment's node_number_mappings hash.

# Attributes

* `max_nodes`: The maximum number of tickr nodes that you will ever have in your
cluster.
* `starting_offset`: The first ID that you would like your tickr cluster to
provide.
* `http_auth_password`: The password to use for HTTP authentication, if any.

# Recipes

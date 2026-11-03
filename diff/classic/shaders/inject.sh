#!/usr/bin/env bash
# Applies one mutation at a time to a sandbox copy of the port (see sandbox.sh) and checks
# that compare.mjs reports it. Never touches the repository files. The mutations are
# `perl -0pi -e` substitutions on the whole file (portable across macOS and Linux).
#   bash inject.sh        (INJECT_DRY_RUN=1 bash inject.sh: only check that each applies)
. "$(dirname "${BASH_SOURCE[0]}")/sandbox.sh"
try() { try_mutant "$1" "$2" perl "$3"; }
try "one char in chunk" chunk_alphatest_fragment.mbt 's/if \( diffuseColor.a == 0.0 \) discard;/if ( diffuseColor.a == 0.0 ) discars;/g'
try "trailing space dropped" chunk_aomap_fragment.mbt 's/USE_CLEARCOAT \) \n/USE_CLEARCOAT )\n/'
try "one char in vsm" lib_vsm.mbt 's/void main/void maim/'
try "one char in ShaderLib-only shader" lib_meshphysical.mbt 's/#define STANDARD/#define STANDARE/'
try "trailing newline added" chunk_begin_vertex.mbt 's/\n?\z/\n  #|\n/'
try "chunk key renamed" shader_chunk.mbt 's/\("bsdfs", /("bsdfz", /g'
try "chunk key order" shader_chunk.mbt 's/^(.*"bsdfs", chunk_bsdfs.*)\n(.*)\n/$2\n$1\n/mg'
try "uniform value" uniforms_lib.mbt 's/uniform_number\(0\.98\)/uniform_number(0.99)/g'
try "uniform order" uniforms_lib.mbt 's/^(.*"map", uniform_null.*)\n(.*)\n/$2\n$1\n/mg'
try "group order" uniforms_lib.mbt 's/^(.*"common", uniforms_lib_common.*)\n(.*)\n/$2\n$1\n/mg'
try "hex color one bit" shader_lib.mbt 's/uniform_color\(0x111111\)/uniform_color(0x111112)/g'
try "Null to 0" shader_lib.mbt 's/\("matcap", uniform_null\(\)\)/("matcap", uniform_number(0.0))/g'
try "physical order" shader_lib.mbt 's/\("standard", shader_lib_standard\),//; s/\("physical", shader_lib_physical\),/("physical", shader_lib_physical), ("standard", shader_lib_standard),/'
try "properties value" uniforms_lib.mbt 's/"shadowIntensity": 1,/"shadowIntensity": 2,/'
try "DFG data digit" dfg_lut_table.mbt 's/0x30b5/0x30b4/g'
try "DFG filter" dfg_lut_data.mbt 's/lut.min_filter = \@core.LinearFilter/lut.min_filter = \@core.NearestFilter/g'
try "DFG needsUpdate dropped" dfg_lut_data.mbt 's/lut.set_needs_update\(true\)/ignore(lut)/g'
try "aliasing: entry shares the group" shader_lib.mbt 's/uniforms: \@core.merge_uniforms\(\[uniforms_lib_points, uniforms_lib_fog\]\)/uniforms: { let m = \@core.merge_uniforms([uniforms_lib_points, uniforms_lib_fog]); m["uvTransform"] = uniforms_lib_points["uvTransform"]; m }/'
try "blank GLSL line removed" chunk_packing.mbt 's/\n  #\|\n/\n/'
finish

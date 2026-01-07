#!/bin/tcsh -f
# Run helper for ROHD Wave Viewer (copied into scripts/)
cp rust/wellen_bridge/target/debug/libwellen_bridge.so build/linux/x64/release/bundle/lib/

setenv LD_LIBRARY_PATH "$PWD/rust/wellen_bridge/target/debug:$LD_LIBRARY_PATH"
echo "LD_LIBRARY_PATH set to: $LD_LIBRARY_PATH"

./build/linux/x64/release/bundle/rohd_wave_viewer surfer/examples/with_8_bit.vcd >& /tmp/rohd_run.log

sed -n '1,200p' /tmp/rohd_run.log

echo '--- debug file ---'
if ( -e /tmp/rohd_signal_debug.log ) then
  sed -n '1,200p' /tmp/rohd_signal_debug.log
else
  echo 'no debug file'
endif

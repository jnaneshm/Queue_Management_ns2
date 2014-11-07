if {$argc != 2} {
    puts "Usage: ns $argv0 <Queue_Mechanism> <case_no>"
    exit
}

# Get command line parameters
set flavor [lindex $argv 0]
set case [lindex $argv 1]
global queue_mech, delay, null3

set delay 0

# Set simulation parameters
switch $case {
	1 {set delay "12.5ms"}
	2 {set delay "20ms"}
	default {puts "Invalid option" 
		exit}
}

switch $flavor {
	"DropTail" {set queue_mech "DropTail"}
	"RED" {set queue_mech "RED"}
	default {puts "Invalid option" 
		exit}
}

# Instantiate a new ns2 simulator
set ns [new Simulator]

set cnt 0;
set tput1 0;
set tput2 0;
set tput3 0;

# Print throughputs at finish
proc finish {} {
    global case ns nf file tput1 tput2 tput3 cnt
    if {$case == 2} {
    puts [format "src1: %.6f Mbps; src2: %.6f Mbps; Ratio: %.2f; src3: %.6f Mbps" [expr $tput1/$cnt] [expr $tput2/$cnt] [expr $tput1/$tput2] [expr $tput3/$cnt]]
    exit 0
    }	
    puts [format "src1: %.6f Mbps; src2: %.6f Mbps; Ratio: %.2f" [expr $tput1/$cnt] [expr $tput2/$cnt] [expr $tput1/$tput2]]
    exit 0
}

# Reccursive procedure to calculate throughput at regular intervals
proc record {} {
    global null1 null2 null3 f1 f2 tput1 tput2 tput3 cnt case
    set ns [Simulator instance]
    set time 0.5
    set bw1 [$null1 set bytes_]
    set bw2 [$null2 set bytes_]
    set now [$ns now]
    set tput1 [expr $tput1+($bw1/$time*8/1000000)]
    set tput2 [expr $tput2+($bw2/$time*8/1000000)]
    set cnt [expr $cnt+1]
    $null1 set bytes_ 0
    $null2 set bytes_ 0
    if {$case == 2} {
    	set bw3 [$null3 set bytes_]
    	set tput3 [expr $tput3+($bw3/$time*8/1000000)]
    	$null3 set bytes_ 0
    }
    $ns at [expr $now+$time] "record"
}

# Topology
set src1 [$ns node]
set src2 [$ns node]
set r1 [$ns node]
set r2 [$ns node]
set rcv1 [$ns node]
set rcv2 [$ns node]
set tcp1 [new Agent/TCP/Reno]
$ns attach-agent $src1 $tcp1

set tcp2 [new Agent/TCP/Reno]
$ns attach-agent $src2 $tcp2

if {$queue_mech == "RED"} {
	Queue/RED set thresh_ 10
	Queue/RED set maxthresh_ 15
	Queue/RED set linterm_ 50
}
$ns duplex-link $src1 $r1 10Mb 1ms $queue_mech
$ns duplex-link $src2 $r1 10Mb 1ms $queue_mech
$ns duplex-link $r1 $r2 1Mb 10ms $queue_mech 
$ns duplex-link $r2 $rcv1 10Mb 1ms $queue_mech
$ns duplex-link $r2 $rcv2 10Mb 1ms $queue_mech
$ns queue-limit $r1 $r2 20
if {$case == 2} {
	global null3
	set H3 [$ns node]
	set H5 [$ns node]
	set udp [new Agent/UDP]
	$ns attach-agent $H3 $udp
	set null3 [new Agent/LossMonitor] 
	$ns attach-agent $H5 $null3
	$ns connect $udp $null3
	set cbr [new Application/Traffic/CBR]
	$cbr attach-agent $udp
	$cbr set type_ CBR
	$cbr set packet_size_ 100
	$cbr set rate_ 1mb
	$ns duplex-link $H3 $r1 10Mb 1ms $queue_mech
	$ns duplex-link $H5 $r2 10Mb 1ms $queue_mech
}

set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1

set ftp2 [new Application/FTP]
$ftp2 attach-agent $tcp2

set null1 [new Agent/TCPSink] 
$ns attach-agent $rcv1 $null1

set null2 [new Agent/TCPSink] 
$ns attach-agent $rcv2 $null2

$ns connect $tcp1 $null1
$ns connect $tcp2 $null2

# Start measuring throughput after 100 seconds
$ns at 30.0 "record"

$ns at 0.0 "$ftp1 start"
$ns at 180.0 "$ftp1 stop"

$ns at 0.0 "$ftp2 start"
$ns at 180.0 "$ftp2 stop"

if {$case == 2} {
$ns at 0.0 "$cbr start"
$ns at 180.0 "$cbr stop"
}
# Finish simulation at 400 seconds
$ns at 180.0 "finish"

$ns run

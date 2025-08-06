/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation;
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

//
// Multi-Node Tap-CSMA Scenario for NS-3
// This scenario supports dynamic number of nodes connected via CSMA network
// Each node is connected to a tap device that bridges to a Docker container
//
// Network topology:
//
//  +----------+     +----------+     +----------+
//  | virtual  |     | virtual  |     | virtual  |
//  |  Linux   |     |  Linux   |     |  Linux   |
//  |   Host   |     |   Host   |     |   Host   |
//  |          |     |          |     |          |
//  |   eth0   |     |   eth0   |     |   eth0   |
//  +----------+     +----------+     +----------+
//       |                |                |
//  +----------+     +----------+     +----------+
//  |  Linux   |     |  Linux   |     |  Linux   |
//  |  Bridge  |     |  Bridge  |     |  Bridge  |
//  +----------+     +----------+     +----------+
//       |                |                |
//  +----------+     +----------+     +----------+
//  |"tap-node-1|   |"tap-node-2|   |"tap-node-N|
//  +----------+     +----------+     +----------+
//       |                |                |
//       |       n0       |       n1       |       nN
//       |   +--------+   |   +--------+   |   +--------+
//       +---|  tap   |   |   |  tap   |   |   |  tap   |
//           | bridge |   |   | bridge |   |   | bridge |
//           +--------+   |   +--------+   |   +--------+
//           |  CSMA  |   |   |  CSMA  |   |   |  CSMA  |
//           +--------+   |   +--------+   |   +--------+
//               |             |             |
//               |             |             |
//               |             |             |
//               ===============================
//                      CSMA LAN
//

#include "ns3/core-module.h"
#include "ns3/csma-module.h"
#include "ns3/network-module.h"
#include "ns3/tap-bridge-module.h"
#include "ns3/command-line.h"
#include "ns3/string.h"
#include "ns3/boolean.h"
#include "ns3/global-value.h"

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("MultiNodeTapCsmaScenario");

int
main(int argc, char* argv[])
{
    // Default values
    uint32_t nNodes = 4;  // Default to 4 beacon-chain nodes
    std::string tapPrefix = "tap-beacon";
    double simulationTime = 600.0; // 10 minutes
    std::string dataRate = "100Mbps";
    std::string delay = "6560ns";
    bool verbose = false;

    CommandLine cmd(__FILE__);
    cmd.AddValue("nNodes", "Number of nodes", nNodes);
    cmd.AddValue("tapPrefix", "Prefix for tap device names", tapPrefix);
    cmd.AddValue("simulationTime", "Simulation time in seconds", simulationTime);
    cmd.AddValue("dataRate", "CSMA channel data rate", dataRate);
    cmd.AddValue("delay", "CSMA channel delay", delay);
    cmd.AddValue("verbose", "Enable verbose logging", verbose);
    cmd.Parse(argc, argv);

    if (verbose)
    {
        LogComponentEnable("MultiNodeTapCsmaScenario", LOG_LEVEL_INFO);
        LogComponentEnable("TapBridge", LOG_LEVEL_INFO);
        LogComponentEnable("CsmaChannel", LOG_LEVEL_INFO);
    }

    std::cout << "Multi-Node Tap-CSMA Scenario" << std::endl;
    std::cout << "Number of nodes: " << nNodes << std::endl;
    std::cout << "Tap prefix: " << tapPrefix << std::endl;
    std::cout << "Simulation time: " << simulationTime << " seconds" << std::endl;
    std::cout << "CSMA data rate: " << dataRate << std::endl;
    std::cout << "CSMA delay: " << delay << std::endl;

    //
    // We are interacting with the outside, real, world.  This means we have to
    // interact in real-time and therefore means we have to use the real-time
    // simulator and take the time to calculate checksums.
    //
    GlobalValue::Bind("SimulatorImplementationType", StringValue("ns3::RealtimeSimulatorImpl"));
    GlobalValue::Bind("ChecksumEnabled", BooleanValue(true));

    //
    // Create the specified number of nodes
    //
    NodeContainer nodes;
    nodes.Create(nNodes);

    std::cout << "Created " << nNodes << " nodes" << std::endl;

    //
    // Use a CsmaHelper to get a CSMA channel created, and the needed net
    // devices installed on all of the nodes.  The data rate and delay for the
    // channel can be set through the command-line parser.
    //
    CsmaHelper csma;
    csma.SetChannelAttribute("DataRate", StringValue(dataRate));
    csma.SetChannelAttribute("Delay", StringValue(delay));
    NetDeviceContainer devices = csma.Install(nodes);

    std::cout << "Installed CSMA devices on all nodes" << std::endl;

    //
    // Use the TapBridgeHelper to connect to the pre-configured tap devices.
    // We go with "UseBridge" mode since the CSMA devices support
    // promiscuous mode and can therefore make it appear that the bridge is
    // extended into ns-3.  The install method essentially bridges the specified
    // tap to the specified CSMA device.
    //
    TapBridgeHelper tapBridge;
    tapBridge.SetAttribute("Mode", StringValue("UseBridge"));

    std::cout << "Connecting tap devices to CSMA devices..." << std::endl;

    for (uint32_t i = 0; i < nNodes; ++i)
    {
        std::string tapDeviceName = tapPrefix + "-" + std::to_string(i + 1);
        std::cout << "Connecting " << tapDeviceName << " to node " << i << std::endl;
        
        tapBridge.SetAttribute("DeviceName", StringValue(tapDeviceName));
        tapBridge.Install(nodes.Get(i), devices.Get(i));
    }

    std::cout << "All tap devices connected successfully" << std::endl;

    //
    // Run the simulation for the specified time
    //
    std::cout << "Starting simulation for " << simulationTime << " seconds..." << std::endl;
    Simulator::Stop(Seconds(simulationTime));
    Simulator::Run();
    Simulator::Destroy();

    std::cout << "Simulation completed successfully" << std::endl;
    return 0;
}

/*
 * ns3 network simulator code
 * Copyright 2023 Carnegie Mellon University.
 * NO WARRANTY. THIS CARNEGIE MELLON UNIVERSITY AND SOFTWARE ENGINEERING INSTITUTE MATERIAL IS FURNISHED ON AN "AS-IS" BASIS. CARNEGIE MELLON UNIVERSITY AND SOFTWARE ENGINEERING INSTITUTE DOES NOT MAKE ANY WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, AS TO ANY MATTER INCLUDING, BUT NOT LIMITED TO, WARRANTY OF FITNESS FOR PURPOSE OR MERCHANTABILITY, EXCLUSIVITY, OR RESULTS OBTAINED FROM USE OF THE MATERIAL. CARNEGIE MELLON UNIVERSITY DOES NOT MAKE ANY WARRANTY OF ANY KIND WITH RESPECT TO FREEDOM FROM PATENT, TRADEMARK, OR COPYRIGHT INFRINGEMENT.
 * Released under a MIT (SEI)-style license, please see license.txt or contact permission@sei.cmu.edu for full terms.
 * [DISTRIBUTION STATEMENT A] This material has been approved for public release and unlimited distribution.  Please see Copyright notice for non-US Government use and distribution.
 * This Software includes and/or makes use of the following Third-Party Software subject to its own license:
 * 1. ns-3 (https://www.nsnam.org/about/) Copyright 2011 nsnam.
 * DM23-0109
 */ 
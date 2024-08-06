/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 7, 2024 at 5:02:19 AM
 *********************************************/

using CP;

tuple ArcInfo {
    string start;
    string end;
}

tuple GoodsInfo {
    string good;
    string origin;
    string destination;
    float weight;
    float maxtime;
    float penalty;              
    // float carben etc
}

{ArcInfo} Arcs = ...; // 定义弧的信息集合 // Define the set of arc information
setof(string) Nodes = ...; // 所有节点，包括起点、终点和转运节点 // All nodes, including origin, destination, and transfer nodes
setof(string) Modes = ...; // 所有运输方式 // All modes of transportation
{GoodsInfo} GoodsDetails = ...; // 每个物品的详细信息，包括起点、终点和重量 // Detailed information of each good, including origin, destination, and weight
setof(string) Goods = {gd.good | gd in GoodsDetails}; // 从GoodsDetails中提取物品集合 // Extract the set of goods from GoodsDetails

float Cost[Arcs][Modes] = ...; // 运输成本 // Transportation cost
float Time[Arcs][Modes] = ...; // 运输时间 // Transportation time
float Capacity[Arcs][Modes] = ...; // 运输能力 // Transportation capacity

dvar boolean x[Goods][Arcs][Modes]; // 选择某条弧上的某种运输方式，用于特定的物品 // Select a specific transportation mode on a specific arc for a particular good
dvar boolean timeViolation[Goods]; // 时间违规变量 // Time violation variable

// 目标函数 运输成本和超时成本 // Objective function: Transportation cost and overtime cost
minimize 
    sum(gd in GoodsDetails, a in Arcs, m in Modes) Cost[a][m] * x[gd.good][a][m] // 运输成本 // Transportation cost
    + sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good]; // 超时成本 // Overtime cost

// 约束条件 // Constraints
subject to {
    // 每个物品从其起点出发 // Each good must depart from its origin
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.start == gd.origin) x[gd.good][a][m] == 1;

    // 每个物品到达其终点 // Each good must arrive at its destination
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.end == gd.destination) x[gd.good][a][m] == 1;

    // 每个物品在转运节点的流量平衡 // Flow balance for each good at transfer nodes
    forall(gd in GoodsDetails, n in Nodes : !(n == gd.origin) && !(n == gd.destination))
        sum(a in Arcs, m in Modes : a.end == n) x[gd.good][a][m] == sum(a in Arcs, m in Modes : a.start == n) x[gd.good][a][m];

    // 总运输时间不能超过最大允许时间 // Total transportation time must not exceed the maximum allowed time
    forall(gd in GoodsDetails)
    	sum(a in Arcs, m in Modes) Time[a][m] * x[gd.good][a][m] <= gd.maxtime + timeViolation[gd.good] * 1e6;

    // 每条弧上的总运输量不能超过其容量限制 // Total transported weight on each arc must not exceed its capacity
    forall(a in Arcs, m in Modes)
        sum(gd in GoodsDetails) gd.weight * x[gd.good][a][m] <= Capacity[a][m];
        
}

// 输出结果 // Output results
execute {
    writeln("Optimal transportation plan:");
    for(var gd in GoodsDetails) {
        for(var a in Arcs) {
            for(var m in Modes) {
                if(x[gd.good][a][m] > 0.5) {
                    writeln("Transport good ", gd.good, " on arc from ", a.start, " to ", a.end, " using mode ", m);
                }
            }
        }
    }
   	for(var gd in GoodsDetails) {
        if (timeViolation[gd.good] == 1) {
            writeln("Time violation for good: ", gd.good);
        }
  	}    
}
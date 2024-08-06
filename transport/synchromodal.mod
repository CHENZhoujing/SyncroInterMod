/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 5, 2024 at 3:37:23 PM
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
}

{ArcInfo} Arcs = ...; // 定义弧的信息集合 // Define the set of arc information
setof(string) Nodes = ...; // 所有节点，包括起点、终点和转运节点 // All nodes, including origin, destination, and transfer nodes
setof(string) Modes = ...; // 所有运输方式 // All modes of transportation
{GoodsInfo} GoodsDetails = ...; // 每个物品的详细信息，包括起点、终点和重量 // Detailed information of each good, including origin, destination, and weight
setof(string) Goods = {gd.good | gd in GoodsDetails}; // 从GoodsDetails中提取物品集合 // Extract the set of goods from GoodsDetails

float Cost[Arcs][Modes] = ...; // 固定服务的运输成本 // Transportation cost for fixed services
float Time[Arcs][Modes] = ...; // 固定服务的运输时间 // Transportation time for fixed services
float Capacity[Arcs][Modes] = ...; // 固定服务的运输能力 // Transportation capacity for fixed services

float fCost[Arcs][Modes] = ...; // 灵活服务的运输成本 // Transportation cost for flexible services
float fTime[Arcs][Modes] = ...; // 灵活服务的运输时间 // Transportation time for flexible services
float fCapacity[Arcs][Modes] = ...; // 灵活服务的运输能力 // Transportation capacity for flexible services

dvar boolean x[Goods][Arcs][Modes]; // 选择某条弧上的某种固定运输方式，用于特定的物品 // Select a specific fixed transportation mode on a specific arc for a particular good
dvar boolean fx[Goods][Arcs][Modes]; // 选择某条弧上的某种灵活运输方式，用于特定的物品 // Select a specific flexible transportation mode on a specific arc for a particular good
dvar boolean timeViolation[Goods]; // 时间违规变量 // Time violation variable

// 目标函数 // Objective function
minimize 
    sum(gd in GoodsDetails, a in Arcs, m in Modes) (Cost[a][m] * x[gd.good][a][m] + fCost[a][m] * fx[gd.good][a][m]) // 运输成本 // Transportation cost
    + sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good]; // 超时成本 // Overtime cost

// 约束条件 // Constraints
subject to {
    // 每个物品从其起点出发 // Each good must depart from its origin
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.start == gd.origin) (x[gd.good][a][m] + fx[gd.good][a][m]) == 1;

    // 每个物品到达其终点 // Each good must arrive at its destination
    forall(gd in GoodsDetails)
        sum(a in Arcs, m in Modes : a.end == gd.destination) (x[gd.good][a][m] + fx[gd.good][a][m]) == 1;

    // 每个物品在转运节点的流量平衡 // Flow balance for each good at transfer nodes
    forall(gd in GoodsDetails, n in Nodes : !(n == gd.origin) && !(n == gd.destination))
        sum(a in Arcs, m in Modes : a.end == n) (x[gd.good][a][m] + fx[gd.good][a][m]) ==
        sum(a in Arcs, m in Modes : a.start == n) (x[gd.good][a][m] + fx[gd.good][a][m]);

    // 总运输时间不能超过最大允许时间 // Total transportation time must not exceed the maximum allowed time
    forall(gd in GoodsDetails)
    	sum(a in Arcs, m in Modes) (Time[a][m] * x[gd.good][a][m] + fTime[a][m] * fx[gd.good][a][m]) <= gd.maxtime + timeViolation[gd.good] * 1e6;

    // 每条弧上的总运输量不能超过其容量限制 // Total transported weight on each arc must not exceed its capacity
    forall(a in Arcs, m in Modes)
        sum(gd in GoodsDetails) (gd.weight * x[gd.good][a][m] + gd.weight * fx[gd.good][a][m]) <= Capacity[a][m] + fCapacity[a][m];
        
    // 灵活服务在固定服务满载之后才会启用 // Flexible service is enabled only after the fixed service is fully utilized
    forall(gd in GoodsDetails, a in Arcs, m in Modes)
        fx[gd.good][a][m] <= x[gd.good][a][m];
}

// 输出结果 // Output results
execute {
    writeln("Optimal transportation plan:");
    for(var gd in GoodsDetails) {
        for(var a in Arcs) {
            for(var m in Modes) {
                if(x[gd.good][a][m] > 0.5) {
                    writeln("Transport good ", gd.good, " on arc from ", a.start, " to ", a.end, " using fixed mode ", m);
                }
                if(fx[gd.good][a][m] > 0.5) {
                    writeln("Transport good ", gd.good, " on arc from ", a.start, " to ", a.end, " using flexible mode ", m);
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

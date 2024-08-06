/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 21, 2024 at 4:01:47 PM
 *********************************************/

using CPLEX;

// 每趟服务的信息集合
// Set of all service information
tuple ServiceInfo {
    string modality;         // 运输方式 Mode of transport
    string origin;           // 起点 Origin node
    string destination;      // 终点 Destination node
    int capacity;            // 运输容量 Capacity of the service
    float departuretime;     // 出发时间 Departure time
    float arrivaltime;       // 到达时间 Arrival time
    float transitcost;       // 运输成本 Transit cost
    float carbonemissions;   // 碳排放量 Carbon emissions
}

// 每个物品的详细信息
// Set of detailed information for each good
tuple GoodInfo {
    string good;             // 物品名称或标识 Name or identifier of the good
    string origin;           // 起点 Origin node
    string destination;      // 终点 Destination node
    int capacity;            // 容量 Capacity of the good
    float departuretime;     // 出发时间 Departure time
    float arrivaltime;       // 到达时间 Arrival time
    float penalty;           // 超时惩罚 Penalty for late delivery
}

{ServiceInfo} Services = ...; // 每趟服务的信息集合 Set of all service information
setof(string) Nodes = ...;     // 所有节点，包括起点、终点和转运节点 Set of all nodes, including origins, destinations, and transshipment nodes
setof(string) Modes = ...;     // 所有运输方式 Set of all transportation modes
{GoodInfo} GoodsDetails = ...; // 每个物品的详细信息 Set of detailed information for each good
setof(string) Goods = {gd.good | gd in GoodsDetails}; // 从GoodsDetails中提取物品集合 Set of goods extracted from GoodsDetails

dvar int+ x[Goods][Services]; // 货物在某个服务上的运输量 Transportation quantity of each good on each service
dvar boolean timeViolation[Goods]; // 时间违规变量 Time violation variable

// 目标函数 运输成本和超时成本
// Objective function: transportation cost and overtime cost
minimize 
    sum(gd in GoodsDetails, s in Services) s.transitcost * x[gd.good][s] // 运输成本 Transportation cost 
    + sum(gd in GoodsDetails, s in Services) s.carbonemissions * x[gd.good][s] // 碳排放成本 Carbon emissions cost
    + sum(gd in GoodsDetails, s in Services) gd.penalty * timeViolation[gd.good] * x[gd.good][s]; // 超时成本 Overtime cost

// 约束条件
// Constraints
subject to {
    forall(gd in GoodsDetails) {
        // 每个物品从其起点出发，运输量等于其总量
        // Each good must depart from its origin with the total quantity equal to its capacity
        sum(s in Services: s.origin == gd.origin) x[gd.good][s] == gd.capacity;

        // 每个物品到达其终点，运输量等于其总量
        // Each good must arrive at its destination with the total quantity equal to its capacity
        sum(s in Services: s.destination == gd.destination) x[gd.good][s] == gd.capacity;

        // 物品的出发时间限制早于服务开始时间才能使用该服务
        // Goods can only use a service if their departure time is before or equal to the service's departure time
        forall(s in Services: s.origin == gd.origin)
            x[gd.good][s] == 0 || gd.departuretime <= s.departuretime;

        // 物品的到达时间限制于服务结束时间则超时
        // Time violation occurs if the arrival time of the service exceeds the good's arrival time limit
        forall(s in Services: s.origin == gd.origin)
            x[gd.good][s] == 0 || s.arrivaltime <= gd.arrivaltime + 1e6 * timeViolation[gd.good];
    }
    
    forall(gd in GoodsDetails) {
        // 确保顺序服务在到达和出发时间上可行
        // Ensure sequential services are feasible based on arrival and departure times
        forall(s1 in Services, s2 in Services : s1.destination == s2.origin)
            x[gd.good][s1] == 0 || x[gd.good][s2] == 0 || s1.arrivaltime <= s2.departuretime;
    }

    // 每条服务上的总运输量不能超过其容量限制
    // Total transportation quantity on each service cannot exceed its capacity
    forall(s in Services)
        (s.modality == "Truck") || (sum(gd in GoodsDetails) x[gd.good][s] <= s.capacity);
   
    // 每个物品在转运节点的流量平衡
    // Flow balance at transshipment nodes for each good
    forall(gd in GoodsDetails, n in Nodes : !(n == gd.origin) && !(n == gd.destination))
        sum(s in Services : s.destination == n) x[gd.good][s] == sum(s in Services : s.origin == n) x[gd.good][s];      
}

execute {
    writeln("Transport Paths and Overtime Information:");
    // 输出每个货物的运输路径
    // Output the transportation path for each good
    for (var gd in GoodsDetails) {
        writeln("Good: ", gd.good);
        var totalTransported = 0;
        for (var s in Services) {
            if (x[gd.good][s] > 0) {
                writeln("  - Service: ", s.modality, " from ", s.origin, " to ", s.destination, 
                        ", Transported Quantity: ", x[gd.good][s]);
                totalTransported += x[gd.good][s];
            }
        }
        // 检查是否超时
        // Check for overtime status
        if (timeViolation[gd.good] == 1) {
            writeln("  - Status: Overtime");
        } else {
            writeln("  - Status: On Time");
        }
        writeln("  - Total Transported: ", totalTransported, "/", gd.capacity);
    }
}
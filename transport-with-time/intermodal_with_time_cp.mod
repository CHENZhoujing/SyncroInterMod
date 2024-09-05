/*********************************************
 * OPL 22.1.1.0 Model
 * Author: czj
 * Creation Date: Jul 21, 2024 at 4:01:47 PM
 *********************************************/

using CPLEX;

// Set of all service information
tuple ServiceInfo {
    string modality;         // Mode of transport
    string origin;           // Origin node
    string destination;      // Destination node
    int capacity;            // Capacity of the service
    float departuretime;     // Departure time
    float arrivaltime;       // Arrival time
    float transitcost;       // Transit cost
    float carbonemissions;   // Carbon emissions
}

// Set of detailed information for each good
tuple GoodInfo {
    string good;             // Name or identifier of the good
    string origin;           // Origin node
    string destination;      // Destination node
    int capacity;            // Capacity of the good
    float departuretime;     // Departure time
    float arrivaltime;       // Arrival time
    float penalty;           // Penalty for late delivery
}

{ServiceInfo} Services = ...; // Set of all service information
setof(string) Nodes = ...;     // Set of all nodes, including origins, destinations, and transshipment nodes
setof(string) Modes = ...;     // Set of all transportation modes

{GoodInfo} GoodsDetails = ...; // Set of detailed information for each good
setof(string) Goods = {gd.good | gd in GoodsDetails}; // Set of goods extracted from GoodsDetails

dvar int+ x[Goods][Services]; // Transportation quantity of each good on each service
dvar boolean timeViolation[Goods]; // Time violation variable
dvar boolean timeViolation2[Goods]; // Time violation variable to ensure feasibility

float timelimit = ...;
float epgap = ...;

execute PRE_PROCESSING {
  cplex.tilim = timelimit;
  cplex.epgap = epgap;
}

// Objective function: transportation cost and overtime cost
minimize 
    sum(gd in GoodsDetails, s in Services) s.transitcost * x[gd.good][s] // Transportation cost 
    + sum(gd in GoodsDetails, s in Services) s.carbonemissions * x[gd.good][s] // Carbon emissions cost
    + sum(gd in GoodsDetails) gd.penalty * timeViolation[gd.good] * gd.capacity // Penalty cost for late delivery
    + sum(gd in GoodsDetails) 1e9 * timeViolation2[gd.good]; // No-solution penalty cost

// Constraints
subject to {
    forall(gd in GoodsDetails) {
        // Each good must depart from its origin with the total quantity equal to its capacity
        sum(s in Services: s.origin == gd.origin) x[gd.good][s] == gd.capacity;

        // Each good must arrive at its destination with the total quantity equal to its capacity
        sum(s in Services: s.destination == gd.destination) x[gd.good][s] == gd.capacity;

        // Goods can only use a service if their departure time is before or equal to the service's departure time
        forall(s in Services: s.origin == gd.origin)
            s.modality == "Truck" || x[gd.good][s] == 0 || gd.departuretime <= s.departuretime; //+ 1e8 * timeViolation2[gd.good];

        // Time violation occurs if the arrival time of the service exceeds the good's arrival time limit
        forall(s in Services: s.destination == gd.destination)
            s.modality == "Truck" || x[gd.good][s] == 0 || s.arrivaltime <= gd.arrivaltime + 1e8 * timeViolation[gd.good];

        // Balance constraint at intermediate nodes
        forall(n in Nodes: n != gd.origin && n != gd.destination)
            sum(s in Services: s.destination == n) x[gd.good][s] == sum(s in Services: s.origin == n) x[gd.good][s];
    }

    // Ensure sequential services are feasible based on arrival and departure times
    forall(gd in GoodsDetails) {
        forall(s1 in Services, s2 in Services: s1.destination == s2.origin)
            s1.modality == "Truck" || s2.modality == "Truck" || x[gd.good][s1] == 0 || x[gd.good][s2] == 0 || s1.arrivaltime <= s2.departuretime;
    }

    // Total transportation quantity on each service cannot exceed its capacity
    forall(s in Services)
        s.modality == "Truck" || sum(gd in GoodsDetails) x[gd.good][s] <= s.capacity;

    // Ensure non-negative transportation quantity
    forall(gd in GoodsDetails, s in Services)
        x[gd.good][s] >= 0;
}

// Execution block for output
execute {
    writeln("Transport Paths and Overtime Information:");
    // Output the transportation path for each good
    for (var gd in GoodsDetails) {
        writeln("GoodName: ", gd.good);
        writeln("Transported Quantity: ", gd.capacity);
        writeln("Origin to destination: ", gd.origin, " to ", gd.destination);
        for (var s in Services) {
            if (x[gd.good][s] > 0) {
                writeln("  - Service: ", s.modality, " from ", s.origin, " to ", s.destination, 
                        ", Transported Quantity: ", x[gd.good][s]);
            }
        }
        // Check for overtime status
         if (timeViolation[gd.good] == 1) {
            writeln("  - Status: Overtime");
        } else {
            writeln("  - Status: On Time");
        }
        
        if (timeViolation2[gd.good] == 1) {
            writeln("  - Status: No-solution");
        } else {
            writeln("  - Status: OK");
        }
    }
}

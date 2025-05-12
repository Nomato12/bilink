// This is a temporary fix for the transport service map screen 
// to resolve the RenderFlex overflow issue

// The fix needs to be applied to the ListView.builder inside the vehicle list section
// by wrapping the Column with a SingleChildScrollView and setting mainAxisSize: MainAxisSize.min


// To fix the overflow error in the ListView.builder of availableVehicles,
// the Container containing the vehicle card should be wrapped with SingleChildScrollView 
// and the Column should have mainAxisSize set to MainAxisSize.min

// Find in the file around line 590:
// Container(
//   width: 180,
//   margin: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//   decoration: BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(10),
//     boxShadow: [
//       BoxShadow(
//         color: Colors.black12,
//         blurRadius: 5,
//         offset: Offset(0, 2),
//       ),
//     ],
//   ),
//   child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       ...
//     ],
//   ),
// )

// Replace with:
// Container(
//   width: 180,
//   margin: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//   decoration: BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(10),
//     boxShadow: [
//       BoxShadow(
//         color: Colors.black12,
//         blurRadius: 5,
//         offset: Offset(0, 2),
//       ),
//     ],
//   ),
//   child: SingleChildScrollView(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ...
//       ],
//     ),
//   ),
// )

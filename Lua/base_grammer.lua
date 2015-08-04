----cast 1 ---Function
print("----cast 1 ---Function");
function test()
	return 1,2,3;
end

a,b,c = test();

print(a,b,c);

----cast 2 ---对象
print("----cast 2 ---对象");
CUser = {
user_id = 10;
add = function(self,n) self.user_id = self.user_id + n end
}
print(CUser.user_id);
CUser.add(CUser,5);
print(CUser.user_id);


----cast 3 ---Loops
print("----cast 3 ---");
for i=1,10,3 do
	print("i is "..i);
end

----cast 4 ---Arrays\ Hash tables
print("----cast 4 ---Arrays\ Hash tables");
CMerge = {}
CMerge[1] = "xdr1";
CMerge[2] = 22;
CMerge["user"] = "user_xdr";
for key in pairs(CMerge) do
	print("Key["..key.."]="..CMerge[key]);
end

----cast 5 ---Table constructor
print("----cast 5 ---Table constructor ");
TUser = {
color="blue",
{x=0,   y=0},
{x=-10, y=0},
{x=-5, y=4},
{x=0,   y=4}
}
print(TUser["color"],TUser.color)
print(TUser[2].x,TUser[3].y)




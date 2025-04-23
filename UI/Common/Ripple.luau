local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ripple = require(ReplicatedStorage.Packages.Ripple)

export type Motion<T> = Ripple.Motion<T>
export type MotionState = Ripple.MotionState 
export type MotionSolver = Ripple.MotionSolver 
export type MotionGoal = Ripple.MotionGoal 

return Ripple
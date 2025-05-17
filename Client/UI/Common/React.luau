local React = require(game.ReplicatedStorage.Packages.React)

--[[
local createElement = React.createElement
local useEffect = React.useEffect

local Shared = game.ReplicatedStorage.Shared
local NoYield = require(Shared.NoYield)

local ConVar = require(Shared.ConVar)
local react_aggressive_log = ConVar.Declare("react_aggressive_log", 0, ConVar.TEST + ConVar.LOCAL, "")

function React.useEffect(callback, dependencies)
    return NoYield(useEffect, callback, dependencies)
end

function React.createElement(fn, ...: any)
    if react_aggressive_log:GetBool() and type(fn) == "function" then
        print("createElement", debug.info(fn, "n"))
    end

    return createElement(fn :: any, ...)
end
]]--

export type Binding<T> = React.Binding<T>
export type Prop<T> = T | React.Binding<T>
export type BindingUpdater<T> = React.BindingUpdater<T> 
export type LazyComponent<T, P> = React.LazyComponent<T, P> 
export type StatelessFunctionalComponent<P> = React.StatelessFunctionalComponent<P> 
export type ComponentType<P> = React.ComponentType<P> 
export type AbstractComponent<Config, Instance> = React.AbstractComponent<Config, Instance> 
export type ElementType = React.ElementType
export type Element<C> = React.Element<C> 
export type Key = React.Key
export type Ref<ElementType> = React.Ref<ElementType> 
export type Node = React.Node
export type Context<T> = React.Context<T> 
export type ElementProps<C> = React.ElementProps<C> 
export type ElementConfig<T> = React.ElementConfig<T> 
export type ElementRef<C> = React.ElementRef<C> 
export type ComponentClass<P> = React.ComponentClass<P> 
export type PureComponent<Props, State = nil> = React.PureComponent<Props, State> 
export type ReactElement<Props, ElementType = any> = React.ReactElement<Props, ElementType> 
export type ReactChild = React.ReactChild
export type FC<P> = React.FC<P> 
export type ReactNode = React.ReactNode
export type React_AbstractComponent<Props, Instance> = React.React_AbstractComponent<Props, Instance> 
export type React_Component<Props, State> = React.React_Component<Props, State> 
export type React_ComponentType<P> = React.React_ComponentType<P> 
export type React_Context<T> = React.React_Context<T> 
export type React_Element<ElementType> = React.React_Element<ElementType> 
export type React_ElementType = React.React_ElementType
export type React_Node = React.React_Node

return React
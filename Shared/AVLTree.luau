local AVLTree = {}
AVLTree.__index = AVLTree

export type Node<T = any> = {
    Value: T,
    Left: Node<T>?,
    Right: Node<T>?,
    Height: number,
}

export type Class<T = any> = typeof(setmetatable({} :: {
    Root: Node<T>?,
    Compare: (T, T) -> number,

    _lookup: {
        [T]: Node<T>,
    },

    _size: number,
}, AVLTree))

local function inOrder(node: Node)
    if node.Left then
        inOrder(node.Left)
    end

    coroutine.yield(node.Value)
    
    if node.Right then
        inOrder(node.Right)
    end
end

local function preOrder(node: Node)
    coroutine.yield(node.Value)

    if node.Left then
        preOrder(node.Left)
    end

    if node.Right then
        preOrder(node.Right)
    end
end

local function postOrder(node: Node)
    if node.Left then
        postOrder(node.Left)
    end

    if node.Right then
        postOrder(node.Right)
    end

    coroutine.yield(node.Value)
end

local function getHeight(node: Node?): number
    return node and node.Height or 0
end

local function getBalance(node: Node?): number
    if node then
        return getHeight(node.Left) - getHeight(node.Right)
    end

    return 0
end

local function updateHeight(node: Node)
    node.Height = 1 + math.max(getHeight(node.Left), getHeight(node.Right))
end

local function rotateRight(y: Node): Node
    local x = assert(y.Left)
    y.Left = x.Right
    x.Right = y

    updateHeight(y)
    updateHeight(x)

    return x
end

local function rotateLeft(x: Node): Node
    local y = assert(x.Right)
    x.Right = y.Left
    y.Left = x

    updateHeight(x)
    updateHeight(y)

    return y
end

local function insertNode<T>(self: Class<T>, node: Node<T>?, value: T): Node<T>
    if not node then
        local newNode: Node<T> = {
            Value = value,
            Left = nil,
            Right = nil,
            Height = 1,
        }

        self._lookup[value] = newNode
        return newNode
    end

    local comp = self.Compare(value, node.Value)

    if comp < 0 then
        node.Left = insertNode(self, node.Left, value)
    elseif comp > 0 then
        node.Right = insertNode(self, node.Right, value)
    else
        return node
    end

    updateHeight(node)

    local balance = getBalance(node)

    -- Left Left Case
    if balance > 1 and node.Left and self.Compare(value, node.Left.Value) < 0 then
        return rotateRight(node)
    end

    -- Right Right Case
    if balance < -1 and node.Right and self.Compare(value, node.Right.Value) > 0 then
        return rotateLeft(node)
    end

    -- Left Right Case
    if balance > 1 and node.Left and self.Compare(value, node.Left.Value) > 0 then
        node.Left = rotateLeft(node.Left)
        return rotateRight(node)
    end

    -- Right Left Case
    if balance < -1 and node.Right and self.Compare(value, node.Right.Value) < 0 then
        node.Right = rotateRight(node.Right)
        return rotateLeft(node)
    end

    return node
end

local function removeNode<T>(self: Class<T>, node: Node<T>?, value: T): Node<T>?
    if not node then
        return nil
    end

    local comp = self.Compare(value, node.Value)

    if comp < 0 then
        node.Left = removeNode(self, node.Left, value)
    elseif comp > 0 then
        node.Right = removeNode(self, node.Right, value)
    else
        if not node.Left or not node.Right then
            local temp = node.Left or node.Right

            if not temp then
                node = nil
            else
                node = temp
            end
        else
            local temp = node.Right

            while temp.Left do
                temp = temp.Left
            end
            
            local tempVal = temp.Value
            node.Value = tempVal

            self._lookup[tempVal] = node
            node.Right = removeNode(self, node.Right, tempVal)
        end
    end

    if node then
        updateHeight(node)
    else
        return nil
    end

    local balance = getBalance(node)

    -- Left Left Case
    if balance > 1 and getBalance(node.Left) >= 0 then
        return rotateRight(node)
    end

    -- Left Right Case
    if balance > 1 and node.Left and getBalance(node.Left) < 0 then
        node.Left = rotateLeft(node.Left)
        return rotateRight(node)
    end

    -- Right Right Case
    if balance < -1 and getBalance(node.Right) <= 0 then
        return rotateLeft(node)
    end

    -- Right Left Case
    if balance < -1 and node.Right and getBalance(node.Right) > 0 then
        node.Right = rotateRight(node.Right)
        return rotateLeft(node)
    end

    return node
end

function AVLTree.new<T>(compare: (T, T) -> number): Class<T>
    return setmetatable({
        Root = nil,
        Compare = compare,

        _lookup = {},
        _size = 0,
    }, AVLTree)
end

function AVLTree.Insert<T>(self: Class<T>, value: T)
    self.Root = insertNode(self, self.Root, value)
end

function AVLTree.Remove<T>(self: Class<T>, value: T)
    self.Root = removeNode(self, self.Root, value)
    self._lookup[value] = nil
end

function AVLTree.Find<T>(self: Class<T>, value: T): T?
    local node = self.Root

    while node do
        local comp = self.Compare(value, node.Value)

        if comp == 0 then
            return node.Value
        elseif comp < 0 then
            node = node.Left
        else
            node = node.Right
        end
    end

    return nil
end

function AVLTree.Contains(self: Class, value: any): boolean
    local node = self:Find(value)
    return node ~= nil
end

function AVLTree.GetHeight(self: Class): number
    return getHeight(self.Root)
end

function AVLTree.InOrder<T>(self: Class<T>): () -> T?
    return coroutine.wrap(function()
        if self.Root then
            inOrder(self.Root)
        end
    end)
end

function AVLTree.PreOrder<T>(self: Class<T>): () -> T?
    return coroutine.wrap(function()
        if self.Root then
            preOrder(self.Root)
        end
    end)
end

function AVLTree.PostOrder<T>(self: Class<T>): () -> T?
    return coroutine.wrap(function()
        if self.Root then
            postOrder(self.Root)
        end
    end)
end

function AVLTree.First<T>(self: Class<T>): T?
    local node = self.Root

    while node and node.Left do
        node = node.Left
    end

    return node and node.Value
end

function AVLTree.Last<T>(self: Class<T>): T?
    local node = self.Root

    while node and node.Right do
        node = node.Right
    end

    return node and node.Value
end

function AVLTree.IsEmpty(self: Class): boolean
    return self.Root == nil
end

function AVLTree.Clear(self: Class)
    self.Root = nil
    self._lookup = {}
end

function AVLTree.__iter<T>(self: Class)
    return AVLTree.InOrder(self)
end

return AVLTree
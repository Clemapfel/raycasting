/** **/
export class LinkedListNode<T> {
    public value: T;
    public next: LinkedListNode<T> | undefined;
    public previous: LinkedListNode<T> | undefined;

    constructor(value: T) {
        this.value = value;
        this.next = undefined;
        this.previous = undefined;
    }
}

/** **/
export class List<T> {
    private front : LinkedListNode<T> | undefined;
    private back : LinkedListNode<T> | undefined;
    private count : number = 0;

    /** **/
    get length() : number {
        return this.count;
    }

    /** **/
    public *[Symbol.iterator](): Iterator<LinkedListNode<T>> {
        let current_node = this.front;
        while (current_node !== undefined) {
            yield current_node;
            current_node = current_node.next;
        }
    }

    /** **/
    public has(value: T) {
        let current = this.front;
        while (current !== undefined) {
            if (current.value == value)
                return true;

            current = current.next;
        }

        return false;
    }

    /** **/
    public remove(value: T): boolean;
    public remove(node: LinkedListNode<T>): boolean;
    public remove(input_target: T | LinkedListNode<T>): boolean {
        let node_to_remove: LinkedListNode<T> | undefined = undefined;

        if (input_target instanceof LinkedListNode) {
            node_to_remove = input_target;
        } else {
            let current_node = this.front;
            while (current_node !== undefined) {
                if (current_node.value == input_target) {
                    node_to_remove = current_node;
                    break;
                }
                current_node = current_node.next;
            }
        }

        if (node_to_remove === undefined)
            return false;

        if (node_to_remove.previous !== undefined)
            node_to_remove.previous.next = node_to_remove.next;
        else
            this.front = node_to_remove.next;

        if (node_to_remove.next !== undefined)
            node_to_remove.next.previous = node_to_remove.previous;
        else
            this.back = node_to_remove.previous;

        this.count -= 1;
        return true;
    }

    /** **/
    public getPosition(value : T) {
        let current = this.front;
        let position = 0;
        while (current !== undefined) {
            if (current.value == value)
                return position;

            current = current.next;
            position += 1;
        }

        return undefined;
    }

    /** **/
    public getFront() : T | undefined {
        if (this.front === undefined) return undefined;
        return this.front.value;
    }

    /** **/
    public popFront() : T | undefined {
        if (this.front === undefined) return undefined;

        const value = this.front.value;
        this.front = this.front.next;
        if (this.front !== undefined)
            this.front.previous = undefined;
        else
            this.back = undefined;

        this.count -= 1;
        return value;
    }

    /** **/
    public pushFront(value: T) : void {
        const node = new LinkedListNode(value);
        node.next = this.front;
        if (this.front !== undefined)
            this.front.previous = node;
        else
            this.back = node;

        this.front = node;
        this.count += 1;
    }

    /** **/
    public getBack() : T | undefined {
        if (this.back === undefined) return undefined;
        return this.back.value;
    }

    /** **/
    public popBack() : T | undefined {
        if (this.back === undefined) return undefined;

        const value = this.back.value;
        this.back = this.back.previous;
        if (this.back !== undefined)
            this.back.next = undefined;
        else
            this.front = undefined;

        this.count -= 1;
        return value;
    }

    /** **/
    public pushBack(value: T) : void {
        const node = new LinkedListNode(value);
        node.previous = this.back;

        if (this.back !== undefined)
            this.back.next = node;
        else
            this.front = node;

        this.count += 1;
        this.back = node;
    }
}
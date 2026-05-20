class LinkedListNode<T> {
    public value: T;
    public next: LinkedListNode<T> | undefined;
    public previous: LinkedListNode<T> | undefined;

    constructor(value: T) {
        this.value = value;
        this.next = undefined;
        this.previous = undefined;
    }
}

export class List<T> {
    private front : LinkedListNode<T> | undefined;
    private back : LinkedListNode<T> | undefined;
    private count : number = 0;

    get length() : number {
        return this.count;
    }

    public has(value: T) {
        let current = this.front;
        while (current !== undefined) {
            if (current.value == value)
                return true;

            current = current.next;
        }

        return false;
    }

    public remove(value: T): boolean {
        let node = this.front;
        while (node !== undefined) {
            if (node.value == value)
                break;

            node = node.next;
        }

        if (node === undefined || node.value !== value)
            return false;

        if (node.previous !== undefined)
            node.previous.next = node.next;
        else
            this.front = node.next;

        if (node.next !== undefined)
            node.next.previous = node.previous;
        else
            this.back = node.previous;

        this.count -= 1;
        return true;
    }

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

    public getFront() : T | undefined {
        if (this.front === undefined) return undefined;
        return this.front.value;
    }

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

    public getBack() : T | undefined {
        if (this.back === undefined) return undefined;
        return this.back.value;
    }

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
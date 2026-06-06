/** **/
class Deque<T> {
    private items: T[] = [];

    /** **/
    public pop() : T | undefined {
        return this.popBack();
    }

    /** **/
    public push(item : T) : void {
        this.pushBack(item);
    }

    /** **/
    public peek(item : T) : T | undefined {
        return this.getBack();
    }

    /** **/
    public pushFront(item: T): void {
        this.items.unshift(item);
    }

    /** **/
    public pushBack(item: T): void {
        this.items.push(item);
    }

    /** **/
    public popFront(): T | undefined {
        return this.items.shift();
    }

    /** **/
    public popBack() : T | undefined {
        return this.items.pop();
    }

    /** **/
    public getFront(): T | undefined {
        return this.items[0];
    }

    /** **/
    public getBack(): T | undefined {
        return this.items[this.items.length - 1];
    }

    /** **/
    public get length(): number {
        return this.items.length;
    }

    public isEmpty(): boolean {
        return this.items.length === 0;
    }
}
